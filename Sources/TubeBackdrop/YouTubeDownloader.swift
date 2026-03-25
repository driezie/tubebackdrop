import Foundation

enum YouTubeDownloader {
  /// Prefers 4K (2160p) or higher when available; merges best audio.
  private static let formatSelector =
    "bestvideo[height>=2160]+bestaudio/bestvideo[height>=1440]+bestaudio/bestvideo+bestaudio/best"

  private static let downloadPercentPattern = try! NSRegularExpression(
    pattern: #"\[download\][^\n]*?(\d+\.?\d*)%"#,
    options: []
  )

  /// Parses yt-dlp stderr lines like `[download]  45.2% of ...` into 0...1.
  static func fractionFromProgressLine(_ line: String) -> Double? {
    let ns = line as NSString
    let range = NSRange(location: 0, length: ns.length)
    guard let m = downloadPercentPattern.firstMatch(in: line, options: [], range: range),
          m.numberOfRanges > 1,
          let r = Range(m.range(at: 1), in: line),
          let pct = Double(line[r])
    else { return nil }
    return min(1, max(0, pct / 100))
  }

  static func ytDlpPaths() -> [String] {
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    return [
      "/opt/homebrew/bin/yt-dlp",
      "/usr/local/bin/yt-dlp",
      "\(home)/.local/bin/yt-dlp",
    ]
  }

  static func findYtDlp() -> String? {
    for path in ytDlpPaths() where FileManager.default.isExecutableFile(atPath: path) {
      return path
    }
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/which")
    p.arguments = ["yt-dlp"]
    let out = Pipe()
    p.standardOutput = out
    p.standardError = Pipe()
    do {
      try p.run()
      p.waitUntilExit()
    } catch {
      return nil
    }
    let data = out.fileHandleForReading.readDataToEndOfFile()
    let s = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .newlines) ?? ""
    if !s.isEmpty, FileManager.default.isExecutableFile(atPath: s) { return s }
    return nil
  }

  struct Result {
    let outputPath: URL
    let title: String?
  }

  static func download(
    youtubeURL: String,
    outputDir: URL,
    id: UUID,
    progress: @escaping (_ message: String, _ fraction01: Double?) -> Void
  ) async throws -> Result {
    guard let ytdlp = findYtDlp() else {
      throw NSError(
        domain: "TubeBackdrop",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Install yt-dlp: brew install yt-dlp ffmpeg"]
      )
    }

    let base = id.uuidString
    let template = outputDir.appendingPathComponent("\(base).%(ext)s").path

    progress("Starting download…", 0)

    let args: [String] = [
      "-f", formatSelector,
      "--merge-output-format", "mp4",
      "-o", template,
      "--no-playlist",
      "--no-warnings",
      "--newline",
      youtubeURL,
    ]

    try await runProcess(executable: ytdlp, arguments: args) { line in
      let frac = fractionFromProgressLine(line)
      progress(line, frac)
    }

    progress("Finalizing…", 1)

    guard let file = findLargestFile(base: base, in: outputDir) else {
      throw NSError(
        domain: "TubeBackdrop",
        code: 2,
        userInfo: [NSLocalizedDescriptionKey: "Download finished but no output file named \(base).* was found."]
      )
    }

    return Result(outputPath: file, title: nil)
  }

  private static func findLargestFile(base: String, in dir: URL) -> URL? {
    let fm = FileManager.default
    guard let contents = try? fm.contentsOfDirectory(
      at: dir,
      includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey]
    ) else { return nil }

    let candidates = contents.filter { url in
      let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
      if isDir { return false }
      return url.deletingPathExtension().lastPathComponent == base
    }

    return candidates.max { a, b in
      let sa = (try? a.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
      let sb = (try? b.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
      return sa < sb
    }
  }

  private static func runProcess(
    executable: String,
    arguments: [String],
    lineHandler: @escaping (String) -> Void
  ) async throws {
    try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
      DispatchQueue.global(qos: .userInitiated).async {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: executable)
        p.arguments = arguments
        let errPipe = Pipe()
        p.standardOutput = Pipe()
        p.standardError = errPipe

        var stderrBuffer = Data()
        var lineRemainder = ""

        errPipe.fileHandleForReading.readabilityHandler = { h in
          let d = h.availableData
          guard !d.isEmpty else { return }
          stderrBuffer.append(d)
          guard let chunk = String(data: d, encoding: .utf8) else { return }
          lineRemainder.append(contentsOf: chunk)
          while let nl = lineRemainder.firstIndex(of: "\n") {
            let raw = String(lineRemainder[..<nl])
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            let next = lineRemainder.index(after: nl)
            lineRemainder = String(lineRemainder[next...])
            if !line.isEmpty { lineHandler(line) }
          }
        }

        do {
          try p.run()
          p.waitUntilExit()
          errPipe.fileHandleForReading.readabilityHandler = nil

          let tail = lineRemainder.trimmingCharacters(in: .whitespacesAndNewlines)
          if !tail.isEmpty { lineHandler(tail) }

          if p.terminationStatus != 0 {
            let errStr =
              String(data: stderrBuffer, encoding: .utf8)?
              .trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown error"
            cont.resume(throwing: NSError(
              domain: "TubeBackdrop",
              code: Int(p.terminationStatus),
              userInfo: [NSLocalizedDescriptionKey: "yt-dlp failed:\n\(errStr)"]
            ))
            return
          }
          cont.resume()
        } catch {
          errPipe.fileHandleForReading.readabilityHandler = nil
          cont.resume(throwing: error)
        }
      }
    }
  }
}

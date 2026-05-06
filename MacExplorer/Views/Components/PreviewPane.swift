import SwiftUI
import QuickLookUI
import WebKit
import CoreXLSX

/// Preview pane showing file information and a QuickLook preview for selected files.
struct PreviewPane: View {
    @Environment(AppState.self) private var appState
    let tab: TabState

    private var selectedItems: [FileItem] {
        tab.items.filter { tab.selectedItems.contains($0.id) }
    }

    var body: some View {
        Group {
            if selectedItems.count > 1 {
                multiSelectionView
            } else if let item = selectedItems.first {
                VStack(spacing: 0) {
                    fileInfoView(for: item)
                        .padding(12)

                    Divider()

                    if !item.isDirectory {
                        FileTypePreview(url: item.url)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        Spacer()
                    }
                }
            } else {
                VStack {
                    Image(systemName: "doc.richtext")
                        .font(.system(size: 40))
                        .foregroundStyle(.quaternary)
                    Text("Select a file to preview")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(.background)
    }

    @ViewBuilder
    private func fileInfoView(for item: FileItem) -> some View {
        HStack(spacing: 16) {
            Image(nsImage: item.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                    .lineLimit(1)

                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 2) {
                    GridRow {
                        Text("Kind:").foregroundStyle(.secondary)
                        Text(item.kind)
                    }
                    if !item.isDirectory {
                        GridRow {
                            Text("Size:").foregroundStyle(.secondary)
                            Text(item.formattedSize)
                        }
                    }
                    GridRow {
                        Text("Modified:").foregroundStyle(.secondary)
                        Text(item.formattedDate)
                    }
                    GridRow {
                        Text("Path:").foregroundStyle(.secondary)
                        Text(item.url.path)
                            .lineLimit(1)
                            .truncationMode(.head)
                    }
                }
                .font(.callout)
            }

            Spacer()
        }
    }

    @ViewBuilder
    private var multiSelectionView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.on.doc")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("\(selectedItems.count) items selected")
                .font(.headline)

            let totalSize = selectedItems
                .filter { !$0.isDirectory }
                .reduce(Int64(0)) { $0 + $1.size }
            let fileCount = selectedItems.filter { !$0.isDirectory }.count
            let folderCount = selectedItems.filter { $0.isDirectory }.count

            VStack(spacing: 4) {
                if fileCount > 0 {
                    Text("\(fileCount) file\(fileCount == 1 ? "" : "s")")
                        .foregroundStyle(.secondary)
                }
                if folderCount > 0 {
                    Text("\(folderCount) folder\(folderCount == 1 ? "" : "s")")
                        .foregroundStyle(.secondary)
                }
                Text("Total size: \(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))")
                    .foregroundStyle(.secondary)
            }
            .font(.callout)

            Spacer()
        }
        .padding(.top, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - File Type Router

/// Routes file preview to the best renderer based on extension.
struct FileTypePreview: View {
    let url: URL
    private var ext: String { url.pathExtension.lowercased() }

    private static let codeExtensions: Set<String> = [
        "sh", "bash", "zsh", "fish",
        "py", "js", "ts", "jsx", "tsx", "swift", "go", "java", "c", "cpp", "h", "hpp", "m",
        "css", "scss", "less", "json", "yaml", "yml", "toml", "xml", "sql",
        "rb", "rs", "php", "kt", "scala", "md", "txt", "log",
        "env", "conf", "ini", "cfg", "properties",
        "dockerfile", "makefile", "cmake",
        "r", "lua", "perl", "pl", "groovy", "gradle",
        "eml", "mbox"
    ]

    /// Maximum file size for text-based previews (10 MB)
    private static let maxPreviewSize: Int64 = 10 * 1024 * 1024
    /// Maximum file size for XLSX previews (1 MB)
    private static let maxXLSXSize: Int64 = 1 * 1024 * 1024

    private var fileSize: Int64 {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
    }

    var body: some View {
        if ext == "html" || ext == "htm" {
            WebKitPreview(url: url)
        } else if ext == "csv" || ext == "tsv" {
            if fileSize > Self.maxPreviewSize {
                fileTooLargeView
            } else {
                CSVPreview(url: url)
            }
        } else if ext == "xlsx" {
            if fileSize > Self.maxXLSXSize {
                fileTooLargeView
            } else {
                XLSXPreview(url: url)
            }
        } else if Self.codeExtensions.contains(ext) || isCodeByFilename {
            if fileSize > Self.maxPreviewSize {
                fileTooLargeView
            } else {
                CodePreview(url: url)
            }
        } else {
            QuickLookPreview(url: url)
        }
    }

    private var fileTooLargeView: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("File too large to preview")
                .font(.headline)
            Text("\(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var isCodeByFilename: Bool {
        let name = url.lastPathComponent.lowercased()
        return ["dockerfile", "makefile", "gemfile", "rakefile", "podfile",
                ".gitignore", ".dockerignore", ".env", ".zshrc", ".bashrc",
                ".bash_profile", ".vimrc"].contains(name)
    }
}

// MARK: - Code Syntax Highlight Preview

struct CodePreview: View {
    let url: URL
    @State private var htmlContent: String?
    @State private var error: String?
    @Environment(\.colorScheme) private var colorScheme

    private static let maxBytes = 1_000_000

    var body: some View {
        Group {
            if let error {
                Text(error)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let htmlContent {
                CodeWebView(html: htmlContent)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: url) {
            await loadCode()
        }
        .onChange(of: colorScheme) {
            Task { await loadCode() }
        }
    }

    private func loadCode() async {
        do {
            let data = try Data(contentsOf: url)
            let source: String
            if data.count > Self.maxBytes {
                let truncated = data.prefix(Self.maxBytes)
                source = (String(data: truncated, encoding: .utf8) ??
                          String(data: truncated, encoding: .isoLatin1) ?? "")
                        + "\n\n/* ⚠️ File truncated for preview (>\(Self.maxBytes / 1024)KB) */"
            } else {
                source = String(data: data, encoding: .utf8) ??
                         String(data: data, encoding: .isoLatin1) ?? ""
            }
            htmlContent = buildHighlightHTML(source, language: hljsLanguage)
        } catch {
            self.error = "Could not read file"
        }
    }

    private var hljsLanguage: String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "sh", "bash", "zsh", "fish": return "bash"
        case "py": return "python"
        case "js", "jsx": return "javascript"
        case "ts", "tsx": return "typescript"
        case "swift": return "swift"
        case "go": return "go"
        case "java", "groovy", "gradle": return "java"
        case "c", "h", "m": return "c"
        case "cpp", "hpp": return "cpp"
        case "css", "scss", "less": return "css"
        case "json": return "json"
        case "yaml", "yml": return "yaml"
        case "toml": return "toml"
        case "xml": return "xml"
        case "sql": return "sql"
        case "rb": return "ruby"
        case "rs": return "rust"
        case "php": return "php"
        case "kt": return "kotlin"
        case "scala": return "scala"
        case "md": return "markdown"
        case "dockerfile", "makefile", "cmake": return "dockerfile"
        case "ini", "conf", "env", "cfg", "properties": return "ini"
        case "r": return "r"
        case "lua": return "lua"
        case "perl", "pl": return "perl"
        case "txt", "log": return "plaintext"
        default: return "plaintext"
        }
    }

    private func buildHighlightHTML(_ code: String, language: String) -> String {
        let escaped = code
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")

        let isDark = colorScheme == .dark
        let themeCSS = isDark ? atomOneDarkCSS : atomOneLightCSS
        let bgColor = isDark ? "#282c34" : "#fafafa"
        let textColor = isDark ? "#abb2bf" : "#383a42"
        let lineNumColor = isDark ? "#636d83" : "#999"

        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <style>
        \(themeCSS)
        </style>
        <style>
          * { margin: 0; padding: 0; box-sizing: border-box; }
          body {
            font-family: "SF Mono", "Menlo", "Monaco", "Courier New", monospace;
            font-size: 12px;
            line-height: 1.5;
            background: \(bgColor);
            color: \(textColor);
          }
          pre { margin: 0; }
          code.hljs {
            padding: 12px 16px;
            min-height: 100vh;
          }
          table.code-table {
            border-collapse: collapse;
            width: 100%;
          }
          .line-num {
            text-align: right;
            padding: 0 12px 0 8px;
            user-select: none;
            white-space: nowrap;
            vertical-align: top;
            border-right: 1px solid rgba(128,128,128,0.2);
            color: \(lineNumColor);
          }
          .line-code {
            padding-left: 12px;
            white-space: pre;
          }
        </style>
        </head>
        <body>
        <pre><code class="language-\(language)">\(escaped)</code></pre>
        <script>
        \(highlightMinJS)
        </script>
        <script>
        document.addEventListener('DOMContentLoaded', function() {
          var codeEl = document.querySelector('pre code');
          hljs.highlightElement(codeEl);
          // Add line numbers
          var lines = codeEl.innerHTML.split('\\n');
          var table = '<table class="code-table">';
          for (var i = 0; i < lines.length; i++) {
            table += '<tr><td class="line-num">' + (i+1) + '</td><td class="line-code">' + lines[i] + '</td></tr>';
          }
          table += '</table>';
          codeEl.innerHTML = table;
          codeEl.style.padding = '8px 0';
        });
        </script>
        </body>
        </html>
        """
    }

    // Inline the JS and CSS to avoid file-loading issues with SPM resource bundles
    private var highlightMinJS: String {
        guard let url = Bundle.module.url(forResource: "highlight.min", withExtension: "js"),
              let js = try? String(contentsOf: url, encoding: .utf8) else {
            return "/* highlight.js not found */"
        }
        return js
    }

    private var atomOneDarkCSS: String {
        guard let url = Bundle.module.url(forResource: "atom-one-dark.min", withExtension: "css"),
              let css = try? String(contentsOf: url, encoding: .utf8) else {
            return "/* theme not found */"
        }
        return css
    }

    private var atomOneLightCSS: String {
        guard let url = Bundle.module.url(forResource: "atom-one-light.min", withExtension: "css"),
              let css = try? String(contentsOf: url, encoding: .utf8) else {
            return "/* theme not found */"
        }
        return css
    }
}

/// WKWebView that renders inline HTML for code preview
struct CodeWebView: NSViewRepresentable {
    let html: String
    @Environment(\.colorScheme) private var colorScheme

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.setValue(false, forKey: "drawsBackground")
        updateAppearance(webView)
        webView.loadHTMLString(html, baseURL: nil)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        updateAppearance(webView)
        webView.loadHTMLString(html, baseURL: nil)
    }

    private func updateAppearance(_ webView: WKWebView) {
        webView.appearance = NSAppearance(named: colorScheme == .dark ? .darkAqua : .aqua)
    }
}

// MARK: - QuickLook (fallback for PDFs, images, etc.)

struct QuickLookPreview: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> QLPreviewView {
        let view = QLPreviewView(frame: .zero, style: .normal)!
        view.autostarts = true
        view.autoresizingMask = [.width, .height]
        view.previewItem = url as QLPreviewItem
        return view
    }

    func updateNSView(_ nsView: QLPreviewView, context: Context) {
        if (nsView.previewItem as? URL) != url {
            nsView.previewItem = url as QLPreviewItem
        }
    }
}

// MARK: - WebKit Preview (HTML files)

struct WebKitPreview: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        if webView.url != url {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if action.navigationType == .linkActivated,
               let linkURL = action.request.url, !linkURL.isFileURL {
                NSWorkspace.shared.open(linkURL)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }
    }
}

// MARK: - CSV Preview

struct CSVPreview: View {
    let url: URL
    @State private var htmlContent: String?
    @State private var error: String?

    var body: some View {
        Group {
            if let error {
                Text(error)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let htmlContent {
                HTMLStringPreview(html: htmlContent, baseURL: url.deletingLastPathComponent())
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: url) {
            await loadCSV()
        }
    }

    private func loadCSV() async {
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            let delimiter: Character = url.pathExtension.lowercased() == "tsv" ? "\t" : ","
            let lines = content.components(separatedBy: .newlines)
                .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

            guard !lines.isEmpty else {
                error = "Empty file"
                return
            }

            var tableRows = ""
            for (i, line) in lines.enumerated() {
                let fields = parseLine(line, delimiter: delimiter)
                let tag = i == 0 ? "th" : "td"
                let cells = fields.map { "<\(tag)>\(escapeHTML($0))</\(tag)>" }.joined()
                tableRows += "<tr>\(cells)</tr>\n"
            }

            htmlContent = wrapInHTML(tableRows)
        } catch {
            self.error = "Could not read file"
        }
    }

    private func parseLine(_ line: String, delimiter: Character) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        for char in line {
            if char == "\"" { inQuotes.toggle() }
            else if char == delimiter && !inQuotes { fields.append(current); current = "" }
            else { current.append(char) }
        }
        fields.append(current)
        return fields
    }
}

// MARK: - XLSX Preview

struct XLSXPreview: View {
    let url: URL
    @State private var htmlContent: String?
    @State private var error: String?

    var body: some View {
        Group {
            if let error {
                Text(error)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let htmlContent {
                HTMLStringPreview(html: htmlContent, baseURL: url.deletingLastPathComponent())
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: url) {
            await loadXLSX()
        }
    }

    private func loadXLSX() async {
        do {
            guard let file = XLSXFile(filepath: url.path) else {
                error = "Could not open Excel file"
                return
            }

            let workbooks = try file.parseWorkbooks()
            guard let workbook = workbooks.first,
                  let (_, wsPath) = try file.parseWorksheetPathsAndNames(workbook: workbook).first,
                  let worksheet = try? file.parseWorksheet(at: wsPath) else {
                error = "No worksheets found"
                return
            }

            let sharedStrings = try? file.parseSharedStrings()
            let rows = worksheet.data?.rows ?? []

            // Build column index mapping using column letter strings
            let allCols = rows.flatMap { $0.cells.map { $0.reference.column.value } }
            let sortedCols = Array(Set(allCols)).sorted()
            let colIndex: [String: Int] = Dictionary(
                uniqueKeysWithValues: sortedCols.enumerated().map { ($1, $0) }
            )
            let colCount = max(sortedCols.count, 1)

            var tableRows = ""
            for (i, row) in rows.enumerated() {
                var cells = Array(repeating: "", count: colCount)
                for cell in row.cells {
                    let idx = colIndex[cell.reference.column.value] ?? 0
                    if let ss = sharedStrings {
                        cells[idx] = cell.stringValue(ss) ?? cell.value ?? ""
                    } else {
                        cells[idx] = cell.value ?? ""
                    }
                }
                let tag = i == 0 ? "th" : "td"
                let tds = cells.map { "<\(tag)>\(escapeHTML($0))</\(tag)>" }.joined()
                tableRows += "<tr>\(tds)</tr>\n"
            }

            htmlContent = wrapInHTML(tableRows)
        } catch {
            self.error = "Error reading Excel file: \(error.localizedDescription)"
        }
    }
}

// MARK: - HTML String Preview (renders generated HTML)

struct HTMLStringPreview: NSViewRepresentable {
    let html: String
    let baseURL: URL
    @Environment(\.colorScheme) private var colorScheme

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.appearance = NSAppearance(named: colorScheme == .dark ? .darkAqua : .aqua)
        webView.loadHTMLString(html, baseURL: baseURL)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        webView.appearance = NSAppearance(named: colorScheme == .dark ? .darkAqua : .aqua)
        webView.loadHTMLString(html, baseURL: baseURL)
    }
}

// MARK: - Helpers

private func escapeHTML(_ str: String) -> String {
    str.replacingOccurrences(of: "&", with: "&amp;")
       .replacingOccurrences(of: "<", with: "&lt;")
       .replacingOccurrences(of: ">", with: "&gt;")
}

private func wrapInHTML(_ tableRows: String) -> String {
    """
    <!DOCTYPE html>
    <html>
    <head>
    <meta charset="utf-8">
    <style>
      body { margin: 0; font-family: -apple-system, BlinkMacSystemFont, sans-serif; font-size: 12px; }
      table { border-collapse: collapse; width: 100%; }
      th, td { border: 1px solid #ddd; padding: 4px 8px; text-align: left; white-space: nowrap; }
      th { background: #f0f0f0; font-weight: 600; position: sticky; top: 0; }
      tr:nth-child(even) { background: #fafafa; }
      tr:hover td { background: #e8f0fe; }
      @media (prefers-color-scheme: dark) {
        body { background: #1e1e1e; color: #d4d4d4; }
        th { background: #2d2d2d; }
        td { border-color: #3d3d3d; }
        tr:nth-child(even) { background: #252525; }
        tr:hover td { background: #2a2d2e; }
      }
    </style>
    </head>
    <body><table>\(tableRows)</table></body>
    </html>
    """
}

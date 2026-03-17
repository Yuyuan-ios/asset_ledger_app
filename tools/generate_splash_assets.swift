import AppKit
import Foundation

struct Palette {
  static let background = NSColor(
    srgbRed: 0.929,
    green: 0.918,
    blue: 0.898,
    alpha: 1.0
  )
  static let text = NSColor(
    srgbRed: 0.0,
    green: 0.0,
    blue: 0.0,
    alpha: 0.92
  )
  static let shadow = NSColor(
    calibratedWhite: 0.0,
    alpha: 0.035
  )
}

let fileManager = FileManager.default
let root = URL(fileURLWithPath: fileManager.currentDirectoryPath)
let iconURL = root.appendingPathComponent("assets/images/app_icon_source.png")

guard let icon = NSImage(contentsOf: iconURL) else {
  fputs("Missing icon asset at \(iconURL.path)\n", stderr)
  exit(1)
}

func writePNG(
  to url: URL,
  logicalSize: CGSize,
  scale: CGFloat = 1,
  opaque: Bool,
  draw: () -> Void
) throws {
  let scaledSize = CGSize(
    width: logicalSize.width * scale,
    height: logicalSize.height * scale
  )
  let image = NSImage(size: scaledSize)
  image.lockFocus()
  NSGraphicsContext.saveGraphicsState()
  let context = NSGraphicsContext.current!.cgContext
  context.setAllowsAntialiasing(true)
  context.interpolationQuality = .high
  if opaque {
    NSColor.white.setFill()
    CGRect(origin: .zero, size: scaledSize).fill()
  } else {
    NSColor.clear.setFill()
    CGRect(origin: .zero, size: scaledSize).fill()
  }
  context.scaleBy(x: scale, y: scale)
  draw()
  NSGraphicsContext.restoreGraphicsState()
  image.unlockFocus()
  guard
    let tiff = image.tiffRepresentation,
    let rep = NSBitmapImageRep(data: tiff),
    let data = rep.representation(using: .png, properties: [:])
  else {
    throw NSError(domain: "generate_splash_assets", code: 2)
  }
  try data.write(to: url)
}

func drawBrandmark(in bounds: CGRect) {
  let canvasWidth = bounds.width
  let iconSize: CGFloat = 132
  let iconY: CGFloat = 132
  let iconRect = CGRect(
    x: (canvasWidth - iconSize) / 2,
    y: iconY,
    width: iconSize,
    height: iconSize
  )

  let shadow = NSShadow()
  shadow.shadowColor = Palette.shadow
  shadow.shadowBlurRadius = 8
  shadow.shadowOffset = CGSize(width: 0, height: -3)
  NSGraphicsContext.saveGraphicsState()
  shadow.set()
  let iconPath = NSBezierPath(
    roundedRect: iconRect,
    xRadius: iconSize * 0.225,
    yRadius: iconSize * 0.225
  )
  iconPath.addClip()
  icon.draw(
    in: iconRect,
    from: .zero,
    operation: .sourceOver,
    fraction: 1.0,
    respectFlipped: false,
    hints: [.interpolation: NSImageInterpolation.high]
  )
  NSGraphicsContext.restoreGraphicsState()

  let paragraph = NSMutableParagraphStyle()
  paragraph.alignment = .center
  let attrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 24, weight: .semibold),
    .foregroundColor: Palette.text,
    .paragraphStyle: paragraph,
    .kern: -0.2,
  ]
  let text = NSAttributedString(string: "Asset Ledger", attributes: attrs)
  let textRect = CGRect(
    x: 20,
    y: 54,
    width: canvasWidth - 40,
    height: 34
  )
  text.draw(in: textRect)
}

func generateBrandmark(to url: URL, logicalSize: CGSize, scale: CGFloat) throws {
  try writePNG(to: url, logicalSize: logicalSize, scale: scale, opaque: false) {
    NSColor.clear.setFill()
    CGRect(origin: .zero, size: logicalSize).fill()
    drawBrandmark(in: CGRect(origin: .zero, size: logicalSize))
  }
}

func generatePreview(to url: URL) throws {
  let previewSize = CGSize(width: 1290, height: 2796)
  let previewBrandmarkURL = root.appendingPathComponent(
    "ios/Runner/Assets.xcassets/BrandSplashBrandmark.imageset/BrandSplashBrandmark@3x.png"
  )
  guard let previewBrandmark = NSImage(contentsOf: previewBrandmarkURL) else {
    throw NSError(domain: "generate_splash_assets", code: 3)
  }
  try writePNG(to: url, logicalSize: previewSize, opaque: true) {
    Palette.background.setFill()
    CGRect(origin: .zero, size: previewSize).fill()

    let brandmarkSize = CGSize(width: 744, height: 840)
    let brandmarkRect = CGRect(
      x: (previewSize.width - brandmarkSize.width) / 2,
      y: (previewSize.height - brandmarkSize.height) / 2,
      width: brandmarkSize.width,
      height: brandmarkSize.height
    )
    previewBrandmark.draw(
      in: brandmarkRect,
      from: .zero,
      operation: .sourceOver,
      fraction: 1.0,
      respectFlipped: false,
      hints: [.interpolation: NSImageInterpolation.high]
    )
  }
}

let iosLaunchDir = root.appendingPathComponent("ios/Runner/Assets.xcassets/BrandSplashBrandmark.imageset")
let androidDrawableDir = root.appendingPathComponent("android/app/src/main/res/drawable")
let previewURL = fileManager.temporaryDirectory.appendingPathComponent(
  "asset_ledger_splash_preview.png"
)

try generateBrandmark(
  to: iosLaunchDir.appendingPathComponent("BrandSplashBrandmark.png"),
  logicalSize: CGSize(width: 248, height: 310),
  scale: 1
)
try generateBrandmark(
  to: iosLaunchDir.appendingPathComponent("BrandSplashBrandmark@2x.png"),
  logicalSize: CGSize(width: 248, height: 310),
  scale: 2
)
try generateBrandmark(
  to: iosLaunchDir.appendingPathComponent("BrandSplashBrandmark@3x.png"),
  logicalSize: CGSize(width: 248, height: 310),
  scale: 3
)
try generateBrandmark(
  to: androidDrawableDir.appendingPathComponent("splash_brandmark.png"),
  logicalSize: CGSize(width: 248, height: 310),
  scale: 1
)
try generatePreview(to: previewURL)

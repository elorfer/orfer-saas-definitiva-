import Foundation
import google_mobile_ads
import UIKit

class ListTileNativeAdFactory: NSObject, FLTNativeAdFactory {
    func createNativeAd(_ nativeAd: GADNativeAd, customOptions: [AnyHashable : Any]?) -> GADNativeAdView? {
        // Create the main ad view
        let adView = GADNativeAdView()
        
        // 🎨 THEME COLORS FROM FLUTTER
        let isDark = customOptions?["isDark"] as? Bool ?? false
        let adType = customOptions?["adType"] as? String ?? "large"
        let surfaceColorHex = customOptions?["surfaceColor"] as? String ?? (isDark ? "#141414" : "#FFFFFF")
        let accentColorHex = customOptions?["accentColor"] as? String ?? "#8D6E63"
        let textPrimaryHex = customOptions?["textPrimaryColor"] as? String ?? (isDark ? "#F2EFE9" : "#2D2420")
        let textSecondaryHex = customOptions?["textSecondaryColor"] as? String ?? (isDark ? "#BCAAA4" : "#756860")
        
        func hexToColor(_ hex: String) -> UIColor {
            var cString: String = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            if cString.hasPrefix("#") { cString.remove(at: cString.startIndex) }
            if cString.count != 6 { return UIColor.gray }
            var rgbValue: UInt64 = 0
            Scanner(string: cString).scanHexInt64(&rgbValue)
            return UIColor(
                red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
                green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
                blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
                alpha: CGFloat(1.0)
            )
        }
        
        let surfaceColor = hexToColor(surfaceColorHex)
        let accentColor = hexToColor(accentColorHex)
        let textPrimary = hexToColor(textPrimaryHex)
        let textSecondary = hexToColor(textSecondaryHex)
        let onAccentColor = isDark ? UIColor.black : UIColor.white

        // 🏗️ BUILD UI PROGRAMMATICALLY
        adView.backgroundColor = .clear
        
        // Container Card
        let card = UIView()
        card.backgroundColor = surfaceColor
        card.layer.cornerRadius = 16
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOffset = CGSize(width: 0, height: 2)
        card.layer.shadowOpacity = 0.1
        card.layer.shadowRadius = 4
        card.translatesAutoresizingMaskIntoConstraints = false
        adView.addSubview(card)
        
        // Content Stack
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        
        // Header (Ad Badge + Advertiser)
        let header = UIStackView()
        header.axis = .horizontal
        header.spacing = 8
        header.alignment = .center
        
        let badge = UILabel()
        badge.text = "Anuncio"
        badge.font = .systemFont(ofSize: 10, weight: .bold)
        badge.textColor = onAccentColor
        badge.backgroundColor = accentColor
        badge.layer.cornerRadius = 4
        badge.clipsToBounds = true
        badge.textAlignment = .center
        badge.setContentHuggingPriority(.required, for: .horizontal)
        header.addArrangedSubview(badge)
        
        let advertiser = UILabel()
        advertiser.font = .systemFont(ofSize: 12)
        advertiser.textColor = textSecondary
        header.addArrangedSubview(advertiser)
        adView.advertiserView = advertiser
        
        stack.addArrangedSubview(header)
        
        // Media View
        let media = GADMediaView()
        media.backgroundColor = UIColor.black.withAlphaComponent(0.05)
        media.layer.cornerRadius = 8
        media.clipsToBounds = true
        media.translatesAutoresizingMaskIntoConstraints = false
        media.heightAnchor.constraint(equalToConstant: 180).isActive = true
        
        if adType == "small" {
            media.isHidden = true
        } else {
            adView.mediaView = media
        }

        stack.addArrangedSubview(media)

        
        // Headline
        let headline = UILabel()
        headline.font = .systemFont(ofSize: 18, weight: .bold)
        headline.textColor = textPrimary
        headline.numberOfLines = 1
        stack.addArrangedSubview(headline)
        adView.headlineView = headline
        
        // Body
        let body = UILabel()
        body.font = .systemFont(ofSize: 14)
        body.textColor = textSecondary
        body.numberOfLines = 2
        stack.addArrangedSubview(body)
        adView.bodyView = body
        
        // CTA Button
        let cta = UIButton(type: .system)
        cta.backgroundColor = accentColor
        cta.setTitleColor(onAccentColor, for: .normal)
        cta.titleLabel?.font = .systemFont(ofSize: 14, weight: .bold)
        cta.layer.cornerRadius = 24
        cta.heightAnchor.constraint(equalToConstant: 48).isActive = true
        stack.addArrangedSubview(cta)
        adView.callToActionView = cta
        
        // Constraints
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: adView.topAnchor, constant: 12),
            card.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 12),
            card.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -12),
            card.bottomAnchor.constraint(equalTo: adView.bottomAnchor, constant: -12),
            
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
            
            badge.widthAnchor.constraint(equalToConstant: 50),
            badge.heightAnchor.constraint(equalToConstant: 18)
        ])
        
        // Populate
        (adView.headlineView as? UILabel)?.text = nativeAd.headline
        (adView.bodyView as? UILabel)?.text = nativeAd.body
        (adView.advertiserView as? UILabel)?.text = nativeAd.advertiser
        (adView.callToActionView as? UIButton)?.setTitle(nativeAd.callToAction, for: .normal)
        
        adView.nativeAd = nativeAd
        
        return adView
    }
}

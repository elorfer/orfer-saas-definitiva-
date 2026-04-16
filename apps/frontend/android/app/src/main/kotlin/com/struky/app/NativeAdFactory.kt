package com.struky.app

import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.RippleDrawable
import android.view.LayoutInflater
import android.view.View
import android.widget.Button
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.TextView
import androidx.cardview.widget.CardView
import com.struky.app.R
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin

class ListTileNativeAdFactory(private val layoutInflater: LayoutInflater) : GoogleMobileAdsPlugin.NativeAdFactory {

    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: MutableMap<String, Any>?
    ): NativeAdView {
        val adView = layoutInflater.inflate(R.layout.list_tile_native_ad, null) as NativeAdView

        // 🎨 EXTRACCIÓN DE COLORES DINÁMICOS (Desde Flutter)
        val isDark = customOptions?.get("isDark") as? Boolean ?: false
        val adType = customOptions?.get("adType") as? String ?: "large"
        val surfaceColor = customOptions?.get("surfaceColor") as? String ?: (if (isDark) "#141414" else "#FFFFFF")
        val accentColor = customOptions?.get("accentColor") as? String ?: "#8D6E63"
        val textPrimary = customOptions?.get("textPrimaryColor") as? String ?: (if (isDark) "#F2EFE9" else "#2D2420")
        val textSecondary = customOptions?.get("textSecondaryColor") as? String ?: (if (isDark) "#BCAAA4" else "#756860")

        // 🏗️ VINCULAR COMPONENTES
        val card = adView.findViewById<CardView>(R.id.ad_card)
        val advertiser = adView.findViewById<TextView>(R.id.ad_advertiser)
        val badge = adView.findViewById<TextView>(R.id.ad_badge)
        val cta = adView.findViewById<Button>(R.id.ad_call_to_action)
        val mediaView = adView.findViewById<com.google.android.gms.ads.nativead.MediaView>(R.id.ad_media)
        val iconView = adView.findViewById<ImageView>(R.id.ad_app_icon)
        val headline = adView.findViewById<TextView>(R.id.ad_headline)
        val body = adView.findViewById<TextView>(R.id.ad_body)
        val adChoicesContainer = adView.findViewById<com.google.android.gms.ads.nativead.AdChoicesView>(R.id.ad_choices_container)

        // 📏 APLICAR TIPO DE ANUNCIO
        if (adType == "small") {
            mediaView.visibility = View.GONE
        } else {
            mediaView.visibility = View.VISIBLE
            adView.mediaView = mediaView
        }

        // 🎨 APLICAR ESTILOS PROFESIONALES (with try-catch safety)
        try {
            card.setCardBackgroundColor(Color.parseColor(surfaceColor))
        } catch (e: Exception) {
            card.setCardBackgroundColor(if (isDark) Color.parseColor("#141414") else Color.WHITE)
        }
        
        try {
            headline.setTextColor(Color.parseColor(textPrimary))
        } catch (e: Exception) {
            headline.setTextColor(if (isDark) Color.WHITE else Color.BLACK)
        }
        
        try {
            val secondaryColorInt = Color.parseColor(textSecondary)
            body.setTextColor(secondaryColorInt)
            advertiser.setTextColor(secondaryColorInt)
        } catch (e: Exception) {
            val fallbackSecondary = if (isDark) Color.LTGRAY else Color.GRAY
            body.setTextColor(fallbackSecondary)
            advertiser.setTextColor(fallbackSecondary)
        }
        
        // Badge color with safety
        try {
            (badge.background as? GradientDrawable)?.setColor(Color.parseColor(accentColor))
        } catch (e: Exception) {
            (badge.background as? GradientDrawable)?.setColor(if (isDark) Color.DKGRAY else Color.GRAY)
        }
        badge.setTextColor(if (isDark) Color.BLACK else Color.WHITE)

        // CTA Button color & ripple with safety
        try {
            val ripple = cta.background as? RippleDrawable
            val ctaShape = ripple?.findDrawableByLayerId(android.R.id.mask) as? GradientDrawable 
                ?: (ripple?.getDrawable(0) as? GradientDrawable)
            ctaShape?.setColor(Color.parseColor(accentColor))
        } catch (e: Exception) {
            // Silently fail or use default
        }
        cta.setTextColor(if (isDark) Color.BLACK else Color.WHITE)

        // 🛡️ RELLENAR DATOS
        adView.headlineView = headline
        adView.bodyView = body
        adView.advertiserView = advertiser
        adView.callToActionView = cta
        adView.iconView = iconView
        adView.adChoicesView = adChoicesContainer

        nativeAd.headline?.let { headline.text = it }
        nativeAd.body?.let { body.text = it }
        
        nativeAd.icon?.let {
            iconView.setImageDrawable(it.drawable)
            iconView.visibility = View.VISIBLE
        } ?: run {
            iconView.visibility = View.GONE
        }
        nativeAd.advertiser?.let { 
            advertiser.text = it 
            advertiser.visibility = View.VISIBLE
        } ?: run {
            advertiser.visibility = View.GONE
        }

        nativeAd.callToAction?.let {
            cta.text = it
            cta.visibility = View.VISIBLE
        } ?: run {
            cta.visibility = View.INVISIBLE
        }

        // 🚀 VINCULAR NATIVE AD
        adView.setNativeAd(nativeAd)

        return adView
    }
}

package com.struky.app

import com.ryanheise.audioservice.AudioServiceActivity

class MainActivity : AudioServiceActivity() {
    // AudioServiceActivity es requerida para audio_service v0.18.12
    // Proporciona el FlutterEngine correcto y conecta con el sistema de notificaciones
}

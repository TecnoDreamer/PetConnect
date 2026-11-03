package com.petconnect.pet_connect

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        criarCanalDeAvisosDoQr()
    }

    /**
     * Canal dos avisos do QR Code (issue #36). A API manda os pushes neste
     * canal (`qr_avisos`) e o AndroidManifest o define como padrão do FCM.
     * Importância alta: o aviso aparece por cima da tela, como uma mensagem.
     * O tutor pode silenciar o canal nas configurações do Android.
     */
    private fun criarCanalDeAvisosDoQr() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val canal = NotificationChannel(
            "qr_avisos",
            "Avisos do QR Code",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Quando a página do QR do seu pet é aberta ou recebe um relato de quem o encontrou."
        }
        getSystemService(NotificationManager::class.java)?.createNotificationChannel(canal)
    }
}

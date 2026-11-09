package org.sense.mindpulse

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.sense.mindpulse.security.SecureDatabaseChannel

class MainActivity : FlutterActivity() {
    private var secureDatabaseChannel: SecureDatabaseChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Encrypted-database key channel (Milestone J). Registering it does not
        // create a key or open a database; only an explicit Dart call does, and
        // no production code makes that call yet.
        val channel = SecureDatabaseChannel(applicationContext)
        secureDatabaseChannel = channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SecureDatabaseChannel.NAME)
            .setMethodCallHandler(channel)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        // The engine's database leases become orphaned (not released): the
        // SQLCipher driver keeps native connections beyond the engine.
        secureDatabaseChannel?.detach()
        secureDatabaseChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}

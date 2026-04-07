package com.celllocator.app

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.telephony.*
import androidx.annotation.RequiresApi
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        const val METHOD_CHANNEL = "com.celllocator/telephony"
        const val EVENT_CHANNEL = "com.celllocator/tower_stream"
    }

    private var telephonyManager: TelephonyManager? = null
    private var eventSink: EventChannel.EventSink? = null
    private var phoneStateListener: PhoneStateListener? = null
    private var telephonyCallback: Any? = null // TelephonyCallback for API 31+

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        telephonyManager = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager

        // Method channel for one-time queries
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getCellInfo" -> {
                        val info = getCellInfo()
                        if (info != null) result.success(info)
                        else result.error("NO_DATA", "No cell info available", null)
                    }
                    "getSignalStrength" -> {
                        result.success(getSignalStrength())
                    }
                    "getNetworkOperator" -> {
                        result.success(getNetworkOperator())
                    }
                    "getAllCells" -> {
                        result.success(getAllCells())
                    }
                    else -> result.notImplemented()
                }
            }

        // Event channel for streaming tower changes
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    startListening()
                }

                override fun onCancel(arguments: Any?) {
                    stopListening()
                    eventSink = null
                }
            })
    }

    private fun getCellInfo(): Map<String, Any?>? {
        if (ContextCompat.checkSelfPermission(this, android.Manifest.permission.ACCESS_FINE_LOCATION)
            != PackageManager.PERMISSION_GRANTED) {
            return mapOf("error" to "permission_denied")
        }

        return try {
            val tm = telephonyManager ?: return null
            val operator = tm.networkOperator

            val mcc = if (operator.length >= 3) operator.substring(0, 3).toIntOrNull() else null
            val mnc = if (operator.length >= 5) operator.substring(3).toIntOrNull() else null

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                getCellInfoModern(tm, mcc, mnc)
            } else {
                getCellInfoLegacy(tm, mcc, mnc)
            }
        } catch (e: Exception) {
            mapOf("error" to e.message)
        }
    }

    @RequiresApi(Build.VERSION_CODES.Q)
    private fun getCellInfoModern(tm: TelephonyManager, mcc: Int?, mnc: Int?): Map<String, Any?> {
        val cells = tm.allCellInfo
        val servingCell = cells?.firstOrNull { it.isRegistered }

        return when (servingCell) {
            is CellInfoLte -> {
                val id = servingCell.cellIdentity
                mapOf(
                    "type" to "LTE",
                    "mcc" to (id.mccString?.toIntOrNull() ?: mcc),
                    "mnc" to (id.mncString?.toIntOrNull() ?: mnc),
                    "tac" to id.tac,
                    "lac" to id.tac, // TAC used as LAC equivalent in LTE
                    "cid" to id.ci,
                    "pci" to id.pci,
                    "earfcn" to id.earfcn,
                    "rsrp" to servingCell.cellSignalStrength.rsrp,
                    "rsrq" to servingCell.cellSignalStrength.rsrq,
                    "signal_dbm" to servingCell.cellSignalStrength.dbm,
                    "signal_level" to servingCell.cellSignalStrength.level,
                    "operator" to tm.networkOperatorName,
                    "timestamp" to System.currentTimeMillis()
                )
            }
            is CellInfoNr -> {
                val id = servingCell.cellIdentity as CellIdentityNr
                mapOf(
                    "type" to "NR (5G)",
                    "mcc" to (id.mccString?.toIntOrNull() ?: mcc),
                    "mnc" to (id.mncString?.toIntOrNull() ?: mnc),
                    "tac" to id.tac,
                    "lac" to id.tac,
                    "cid" to id.nci,
                    "pci" to id.pci,
                    "signal_dbm" to servingCell.cellSignalStrength.dbm,
                    "signal_level" to servingCell.cellSignalStrength.level,
                    "operator" to tm.networkOperatorName,
                    "timestamp" to System.currentTimeMillis()
                )
            }
            is CellInfoWcdma -> {
                val id = servingCell.cellIdentity
                mapOf(
                    "type" to "WCDMA (3G)",
                    "mcc" to (id.mccString?.toIntOrNull() ?: mcc),
                    "mnc" to (id.mncString?.toIntOrNull() ?: mnc),
                    "tac" to null,
                    "lac" to id.lac,
                    "cid" to id.cid,
                    "psc" to id.psc,
                    "signal_dbm" to servingCell.cellSignalStrength.dbm,
                    "signal_level" to servingCell.cellSignalStrength.level,
                    "operator" to tm.networkOperatorName,
                    "timestamp" to System.currentTimeMillis()
                )
            }
            is CellInfoGsm -> {
                val id = servingCell.cellIdentity
                mapOf(
                    "type" to "GSM (2G)",
                    "mcc" to (id.mccString?.toIntOrNull() ?: mcc),
                    "mnc" to (id.mncString?.toIntOrNull() ?: mnc),
                    "tac" to null,
                    "lac" to id.lac,
                    "cid" to id.cid,
                    "arfcn" to id.arfcn,
                    "signal_dbm" to servingCell.cellSignalStrength.dbm,
                    "signal_level" to servingCell.cellSignalStrength.level,
                    "operator" to tm.networkOperatorName,
                    "timestamp" to System.currentTimeMillis()
                )
            }
            else -> mapOf(
                "type" to "Unknown",
                "mcc" to mcc,
                "mnc" to mnc,
                "operator" to tm.networkOperatorName,
                "timestamp" to System.currentTimeMillis()
            )
        }
    }

    @Suppress("DEPRECATION")
    private fun getCellInfoLegacy(tm: TelephonyManager, mcc: Int?, mnc: Int?): Map<String, Any?> {
        val cellLocation = tm.cellLocation
        return when (cellLocation) {
            is GsmCellLocation -> mapOf(
                "type" to "GSM/WCDMA (Legacy)",
                "mcc" to mcc,
                "mnc" to mnc,
                "lac" to cellLocation.lac,
                "cid" to cellLocation.cid,
                "psc" to cellLocation.psc,
                "signal_dbm" to null,
                "signal_level" to null,
                "operator" to tm.networkOperatorName,
                "timestamp" to System.currentTimeMillis()
            )
            is CdmaCellLocation -> mapOf(
                "type" to "CDMA (Legacy)",
                "mcc" to mcc,
                "mnc" to mnc,
                "base_station_id" to cellLocation.baseStationId,
                "network_id" to cellLocation.networkId,
                "system_id" to cellLocation.systemId,
                "operator" to tm.networkOperatorName,
                "timestamp" to System.currentTimeMillis()
            )
            else -> mapOf(
                "type" to "Unknown",
                "mcc" to mcc,
                "mnc" to mnc,
                "operator" to tm.networkOperatorName,
                "timestamp" to System.currentTimeMillis()
            )
        }
    }

    private fun getAllCells(): List<Map<String, Any?>> {
        if (ContextCompat.checkSelfPermission(this, android.Manifest.permission.ACCESS_FINE_LOCATION)
            != PackageManager.PERMISSION_GRANTED) return emptyList()

        return try {
            val cells = telephonyManager?.allCellInfo ?: return emptyList()
            cells.mapNotNull { cell ->
                when {
                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && cell is CellInfoLte -> {
                        val id = cell.cellIdentity
                        mapOf(
                            "type" to "LTE",
                            "registered" to cell.isRegistered,
                            "cid" to id.ci,
                            "tac" to id.tac,
                            "pci" to id.pci,
                            "signal_dbm" to cell.cellSignalStrength.dbm,
                            "signal_level" to cell.cellSignalStrength.level
                        )
                    }
                    cell is CellInfoGsm -> {
                        val id = cell.cellIdentity
                        mapOf(
                            "type" to "GSM",
                            "registered" to cell.isRegistered,
                            "cid" to id.cid,
                            "lac" to id.lac,
                            "signal_dbm" to cell.cellSignalStrength.dbm,
                            "signal_level" to cell.cellSignalStrength.level
                        )
                    }
                    else -> null
                }
            }
        } catch (e: Exception) {
            emptyList()
        }
    }

    private fun getSignalStrength(): Map<String, Any?> {
        return try {
            val cells = if (ContextCompat.checkSelfPermission(this, android.Manifest.permission.ACCESS_FINE_LOCATION)
                == PackageManager.PERMISSION_GRANTED) {
                telephonyManager?.allCellInfo
            } else null

            val serving = cells?.firstOrNull { it.isRegistered }
            when {
                serving == null -> mapOf("level" to 0, "dbm" to null, "description" to "No signal")
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && serving is CellInfoLte ->
                    mapOf(
                        "level" to serving.cellSignalStrength.level,
                        "dbm" to serving.cellSignalStrength.dbm,
                        "rsrp" to serving.cellSignalStrength.rsrp,
                        "description" to getSignalDescription(serving.cellSignalStrength.level)
                    )
                serving is CellInfoGsm ->
                    mapOf(
                        "level" to serving.cellSignalStrength.level,
                        "dbm" to serving.cellSignalStrength.dbm,
                        "description" to getSignalDescription(serving.cellSignalStrength.level)
                    )
                else -> mapOf("level" to 2, "dbm" to null, "description" to "Signal detected")
            }
        } catch (e: Exception) {
            mapOf("level" to 0, "dbm" to null, "description" to "Error: ${e.message}")
        }
    }

    private fun getSignalDescription(level: Int): String = when (level) {
        0 -> "No Signal"
        1 -> "Poor"
        2 -> "Fair"
        3 -> "Good"
        4 -> "Excellent"
        else -> "Unknown"
    }

    private fun getNetworkOperator(): Map<String, Any?> {
        val tm = telephonyManager ?: return mapOf()
        return mapOf(
            "name" to tm.networkOperatorName,
            "operator" to tm.networkOperator,
            "country_iso" to tm.networkCountryIso,
            "sim_operator" to tm.simOperatorName,
            "network_type" to getNetworkTypeName(tm.dataNetworkType),
            "roaming" to tm.isNetworkRoaming
        )
    }

    private fun getNetworkTypeName(type: Int): String = when (type) {
        TelephonyManager.NETWORK_TYPE_GPRS -> "GPRS (2G)"
        TelephonyManager.NETWORK_TYPE_EDGE -> "EDGE (2G)"
        TelephonyManager.NETWORK_TYPE_UMTS -> "UMTS (3G)"
        TelephonyManager.NETWORK_TYPE_HSDPA -> "HSDPA (3G+)"
        TelephonyManager.NETWORK_TYPE_HSPA -> "HSPA (3G+)"
        TelephonyManager.NETWORK_TYPE_LTE -> "LTE (4G)"
        TelephonyManager.NETWORK_TYPE_NR -> "NR (5G)"
        else -> "Unknown"
    }

    @Suppress("DEPRECATION")
    private fun startListening() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // Use TelephonyCallback for API 31+
            val callback = object : TelephonyCallback(), TelephonyCallback.CellInfoListener {
                override fun onCellInfoChanged(cellInfo: MutableList<CellInfo>) {
                    val info = getCellInfo()
                    activity?.runOnUiThread { eventSink?.success(info) }
                }
            }
            telephonyManager?.registerTelephonyCallback(mainExecutor, callback)
            telephonyCallback = callback
        } else {
            // Use PhoneStateListener for older APIs
            val listener = object : PhoneStateListener() {
                @Deprecated("Deprecated in Java")
                override fun onCellInfoChanged(cellInfo: MutableList<CellInfo>?) {
                    val info = getCellInfo()
                    activity?.runOnUiThread { eventSink?.success(info) }
                }
            }
            @Suppress("DEPRECATION")
            telephonyManager?.listen(listener, PhoneStateListener.LISTEN_CELL_INFO)
            phoneStateListener = listener
        }
    }

    @Suppress("DEPRECATION")
    private fun stopListening() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (telephonyCallback as? TelephonyCallback)?.let {
                telephonyManager?.unregisterTelephonyCallback(it as TelephonyCallback)
            }
        } else {
            phoneStateListener?.let {
                @Suppress("DEPRECATION")
                telephonyManager?.listen(it, PhoneStateListener.LISTEN_NONE)
            }
        }
        phoneStateListener = null
        telephonyCallback = null
    }
}

import 'dart:async';
import 'package:flutter/services.dart';
import './sharesdk_defines.dart';
import './sharesdk_register.dart';
import './sharesdk_map.dart';

typedef void EventHandler(dynamic event);

class SharesdkPlugin {
  static const MethodChannel _channel =
      const MethodChannel('com.mob.sharesdk.methodchannel');
  static const EventChannel _channelReciever =
      const EventChannel('com.mob.sharesdk.restorereceiver');

  static Future<dynamic> regist(ShareSDKRegister register) async {
    // 转为 string key，确保鸿蒙等平台能正确解析
    final Map<String, dynamic> platformsInfo = {};
    register.platformsInfo.forEach((k, v) {
      platformsInfo[k.toString()] = v;
    });
    return await _channel.invokeMethod(
        ShareSDKMethods.regist.name!, platformsInfo);
  }

  static Future<dynamic> targetFilePath(
      String fileName, String fileType, Function(String path) result) async {
    Map args = {"name": fileName, "type": fileType};
    Future<dynamic> callback =
        _channel.invokeMethod(ShareSDKMethods.getSharedFilePath.name!, args);
    callback.then((dynamic response) {
      if (response != null) {
        result(response["path"]);
      }
    });
    return callback;
  }

  static Future<dynamic> share(ShareSDKPlatform platform, SSDKMap params,
      Function(SSDKResponseState, dynamic, dynamic, SSDKError) result) {
    Map args = {"platform": platform.id, "params": params.map};
    Future<dynamic> callback =
        _channel.invokeMethod(ShareSDKMethods.share.name!, args);
    callback.then((dynamic response) {
      if (result != null) {
        result(_state(response), response["userData"],
            response["contentEntity"], SSDKError(rawData: response["error"]));
      }
    });
    return callback;
  }

  static Future<dynamic> shareByMap(ShareSDKPlatform platform, Map params,
      Function(SSDKResponseState, dynamic, dynamic, SSDKError) result) {
    Map args = {"platform": platform.id, "params": params};
    Future<dynamic> callback =
        _channel.invokeMethod(ShareSDKMethods.share.name!, args);
    callback.then((dynamic response) {
      if (result != null) {
        result(_state(response), response["userData"],
            response["contentEntity"], SSDKError(rawData: response["error"]));
      }
    });
    return callback;
  }

  static Future<dynamic> shareWithActivity(
      ShareSDKPlatform platform,
      SSDKMap params,
      Function(SSDKResponseState, dynamic, dynamic, SSDKError) result) {
    Map args = {"platform": platform.id, "params": params.map};
    Future<dynamic> callback =
        _channel.invokeMethod(ShareSDKMethods.shareWithActivity.name!, args);
    callback.then((dynamic response) {
      if (result != null) {
        result(_state(response), response["userData"],
            response["contentEntity"], SSDKError(rawData: response["error"]));
      }
    });
    return callback;
  }

  static Future<dynamic> auth(ShareSDKPlatform platform, Map settings,
      Function(SSDKResponseState, dynamic, SSDKError) result) {
    Map args = {"platform": platform.id, "settings": settings};
    Future<dynamic> callback =
        _channel.invokeMethod(ShareSDKMethods.auth.name!, args);
    callback.then((dynamic response) {
      if (result != null) {
        result(_state(response), response["user"],
            SSDKError(rawData: response["error"]));
      }
    });
    return callback;
  }

  static Future<dynamic> hasAuthed(ShareSDKPlatform platform,
      Function(SSDKResponseState, dynamic, SSDKError) result) {
    Future<dynamic> callback =
        _channel.invokeMethod(ShareSDKMethods.hasAuthed.name!, platform.id);
    callback.then((dynamic response) {
      if (result != null) {
        result(_state(response), response["user"],
            SSDKError(rawData: response["error"]));
      }
    });
    return callback;
  }

  static Future<dynamic> cancelAuth(ShareSDKPlatform platform,
      Function(SSDKResponseState, dynamic, SSDKError) result) {
    Future<dynamic> callback =
        _channel.invokeMethod(ShareSDKMethods.cancelAuth.name!, platform.id);
    callback.then((dynamic response) {
      if (result != null) {
        result(_state(response), response["user"],
            SSDKError(rawData: response["error"]));
      }
    });
    return callback;
  }

  static Future<dynamic> getUserInfo(ShareSDKPlatform platform,
      Function(SSDKResponseState, dynamic, SSDKError) result) {
    Map args = {"platform": platform.id};
    Future<dynamic> callback =
        _channel.invokeMethod(ShareSDKMethods.getUserInfo.name!, args);
    callback.then((dynamic response) {
      if (result != null) {
        result(_state(response), response["user"],
            SSDKError(rawData: response["error"]));
      }
    });
    return callback;
  }

  static Future<dynamic> getUserInfoWithParam(ShareSDKPlatform platform,
      Map settings, Function(SSDKResponseState, dynamic, SSDKError) result) {
    Map args = {"platform": platform.id};
    args.addAll(settings);
    Future<dynamic> callback =
        _channel.invokeMethod(ShareSDKMethods.getUserInfo.name!, args);
    callback.then((dynamic response) {
      if (result != null) {
        result(_state(response), response["user"],
            SSDKError(rawData: response["error"]));
      }
    });
    return callback;
  }

  static Future<dynamic> showMenu(
      dynamic view,
      List<ShareSDKPlatform>? platforms,
      SSDKMap params,
      Function(
              SSDKResponseState, ShareSDKPlatform, dynamic, dynamic, SSDKError)?
          result) {
    List? types;
    if (platforms != null) {
      Iterable<int> ids = platforms.map((ShareSDKPlatform item) => item.id!);
      types = List.from(ids);
    }

    Map args = {"platforms": types, "params": params.map, "view": view};
    Future<dynamic> callback =
        _channel.invokeMethod(ShareSDKMethods.showMenu.name!, args);
    callback.then((dynamic response) {
      if (result != null) {
        result(
            _state(response),
            ShareSDKPlatform(id: response["platform"], name: "null"),
            response["userData"],
            response["contentEntity"],
            SSDKError(rawData: response["error"]));
      }
    });
    return callback;
  }

  static Future<dynamic> showEditor(
      ShareSDKPlatform platform,
      SSDKMap params,
      Function(
              SSDKResponseState, ShareSDKPlatform, dynamic, dynamic, SSDKError)?
          result) {
    Map args = {"platform": platform.id, "params": params.map};
    Future<dynamic> callback =
        _channel.invokeMethod(ShareSDKMethods.showEditor.name!, args);
    callback.then((dynamic response) {
      if (result != null) {
        result(
            _state(response),
            ShareSDKPlatform(id: response["platform"], name: "null"),
            response["userData"],
            response["contentEntity"],
            SSDKError(rawData: response["error"]));
      }
    });
    return callback;
  }

  static Future<dynamic> getPrivacyPolicy(String type, String? language,
      Function(dynamic data, dynamic error) result) {
    Map args = {"type": type};
    if (language != null) {
      args["language"] = language;
    }
    Future<dynamic> callback =
        _channel.invokeMethod(ShareSDKMethods.getPrivacyPolicy.name!, args);
    callback.then((dynamic response) {
      if (result != null) {
        result(response["data"], response["error"]);
      }
    });
    return callback;
  }

  static Future<dynamic> uploadPrivacyPermissionStatus(
      int status, Function(bool success) result,
      {String? appKey, String? appSecret}) {
    Map args = {"status": status};
    if (appKey != null && appKey.isNotEmpty) {
      args["appKey"] = appKey;
    }
    if (appSecret != null && appSecret.isNotEmpty) {
      args["appSecret"] = appSecret;
    }
    Future<dynamic> callback = _channel.invokeMethod(
        ShareSDKMethods.uploadPrivacyPermissionStatus.name!, args);
    callback.then((dynamic response) {
      if (result != null) {
        result(response["success"]);
      }
    }).catchError((Object _) {
      // 通道未实现/调用失败时静默处理，避免未处理的异步异常上报为崩溃。
      // 调用方仍可通过 await 的 try/catch 感知失败。
    });
    return callback;
  }

  static Future<dynamic> activePlatforms() async {
    return await _channel.invokeMethod(ShareSDKMethods.activePlatforms.name!);
  }

  static Future<dynamic> get sdkVersion async {
    return await _channel.invokeMethod(ShareSDKMethods.getVersion.name!);
  }

  static Future<dynamic> openWeChatMiniProgram(
      String userName, String path, int miniProgramType) async {
    Map args = {"userName": userName, "path": path, "type": miniProgramType};
    return await _channel.invokeMethod(
        ShareSDKMethods.openMiniProgram.name!, args);
  }

  static Future<dynamic> isClientInstalled(ShareSDKPlatform platform) async {
    Map args = {"platform": platform.id};
    return await _channel.invokeMethod(
        ShareSDKMethods.isClientInstalled.name!, args);
  }

  /// 获取鸿蒙应用签名 fingerprint 及 MD5（用于 QQ 互联平台配置）
  static Future<Map<String, String>?> getBundleSignatureFingerprint() async {
    final result = await _channel.invokeMethod(
        ShareSDKMethods.getBundleSignatureFingerprint.name!);
    if (result is Map) {
      return Map<String, String>.from(result.map(
          (k, v) => MapEntry(k.toString(), v?.toString() ?? '')));
    }
    return null;
  }

  static SSDKResponseState _state(Map response) {
    SSDKResponseState state = SSDKResponseState.Unknown;
    switch (response["state"]) {
      case 1:
        state = SSDKResponseState.Success;
        break;
      case 2:
        state = SSDKResponseState.Fail;
        break;
      case 3:
        state = SSDKResponseState.Cancel;
        break;
    }
    return state;
  }

  static void addRestoreReceiver(EventHandler onEvent, EventHandler onError) {
    _channelReciever.receiveBroadcastStream().listen(onEvent, onError: onError);
  }
}

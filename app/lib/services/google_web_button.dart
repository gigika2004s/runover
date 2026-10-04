import 'package:flutter/material.dart';
import 'package:google_sign_in_web/web_only.dart';

Widget buildGoogleWebButton() => renderButton(
  configuration: GSIButtonConfiguration(
    type: GSIButtonType.standard,
    text: GSIButtonText.signin,
    theme: GSIButtonTheme.outline,
    size: GSIButtonSize.large,
    shape: GSIButtonShape.rectangular,
    logoAlignment: GSIButtonLogoAlignment.left,
    locale: 'pt-BR',
  ),
);


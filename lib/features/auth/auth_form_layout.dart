import 'package:flutter/material.dart';

/// Layout shared by the sign-in and sign-up pages: the form at the top and a
/// footer at the bottom, scrollable so the keyboard never covers a field.
class AuthFormLayout extends StatelessWidget {
  const AuthFormLayout({super.key, required this.form, required this.footer});

  final Widget form;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(40, 40, 40, 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[form, footer],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

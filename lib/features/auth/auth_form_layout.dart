import 'package:flutter/material.dart';
import 'package:mambo/splash_screen.dart';
import 'package:mambo/theme/tokens.dart';
import 'package:mambo/widgets/botanical.dart';
import 'package:mambo/widgets/fresh_surface.dart';

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
                padding: const EdgeInsets.fromLTRB(
                  FreshSpace.page + 8,
                  FreshSpace.lg,
                  FreshSpace.page,
                  FreshSpace.xl,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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

/// Page frame for the auth forms: a back button to the welcome screen, a
/// light heading with a botanical accent, and the form below it.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.fields,
    required this.footer,
    this.botanical = BotanicalKind.sprig,
  });

  final String title;
  final List<Widget> fields;
  final Widget footer;
  final BotanicalKind botanical;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: '返回',
          onPressed:
              () => Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute<void>(builder: (context) => const SplashScreen()),
                (route) => false,
              ),
        ),
      ),
      body: PaperBackground(
        child: AuthFormLayout(
          form: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FreshHeading(title, botanical: botanical),
                const SizedBox(height: FreshSpace.xxl),
                for (final field in fields) ...[
                  field,
                  const SizedBox(height: FreshSpace.lg),
                ],
              ],
            ),
          ),
          footer: footer,
        ),
      ),
    );
  }
}

/// "No account yet? Sign up"-style line under an auth form.
class AuthFooter extends StatelessWidget {
  const AuthFooter({super.key, required this.question, required this.action, required this.onPressed});

  final String question;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(question, style: Theme.of(context).textTheme.bodyMedium),
        TextButton(onPressed: onPressed, child: Text(action)),
      ],
    );
  }
}

/// Submit button that shows a quiet spinner while waiting.
class AuthSubmitButton extends StatelessWidget {
  const AuthSubmitButton({super.key, required this.label, required this.loading, required this.onPressed});

  final String label;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: FreshSpace.lg),
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        child:
            loading
                ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 1.2),
                )
                : Text(label),
      ),
    );
  }
}

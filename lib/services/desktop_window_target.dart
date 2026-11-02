class DesktopWindowTarget {
  const DesktopWindowTarget({
    required this.handle,
    required this.title,
    required this.application,
  });
  final int handle;
  final String title;
  final String application;

  factory DesktopWindowTarget.fromMap(Map<dynamic, dynamic> map) =>
      DesktopWindowTarget(
        handle: map['handle'] as int,
        title: map['title'] as String,
        application: map['application'] as String,
      );
}

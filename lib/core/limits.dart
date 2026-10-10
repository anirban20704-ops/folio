/// Maximum lengths for user-entered names.
const int kMaxFolderNameLength = 30;
const int kMaxDocNameLength = 40;

String clampName(String name, int max) {
  final t = name.trim();
  return t.length <= max ? t : t.substring(0, max).trimRight();
}

/// Safe default cap (physical pixels) for image decode resolution when no
/// specific display size is known at the call site. Well above any
/// thumbnail/card/avatar size actually used in this app, but far below a
/// full camera photo (often 4000+ px per side on a modern phone) —
/// decoding a full-resolution photo just to shrink it visually is what
/// drives an EXC_RESOURCE memory crash when several such images render
/// into a list/grid at once (e.g. artist avatars, portfolio thumbnails,
/// request inspiration photos).
///
/// Pass this as `cacheWidth` on `Image.network`/`Image.memory` wherever the
/// widget's actual display width/height isn't available to compute a
/// tighter, size-specific cap; Flutter preserves aspect ratio and derives
/// cache height automatically from a single cacheWidth.
const int kMaxImageDecodeDimension = 1024;

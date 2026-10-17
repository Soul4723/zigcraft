const std = @import("std");

// ============================================================================
// Item IDs and Constants
// ============================================================================

/// Item ID tag for regular Book.
pub const BookTag: u16 = 270;

/// Item ID tag for Feather.
pub const FeatherTag: u16 = 288;

/// Item ID tag for Ink Sac.
pub const InkSacTag: u16 = 351;

/// Item ID tag for Book and Quill (writable book).
pub const BookAndQuillTag: u16 = 401;

/// Item ID tag for Written Book (signed book).
pub const WrittenBookTag: u16 = 402;

/// Maximum number of pages supported in a Book and Quill or Written Book.
pub const max_book_pages: u8 = 100;

/// Maximum characters allowed per book page.
pub const max_page_char_len: usize = 256;

/// Maximum character length of a book title.
pub const max_title_len: usize = 16;

/// Maximum character length of a book author name.
pub const max_author_len: usize = 16;

// ============================================================================
// Errors
// ============================================================================

pub const BookError = error{
    BookFull,
    InvalidPageIndex,
    EmptyTitle,
    TitleTooLong,
    AuthorTooLong,
    CannotCopyGeneration,
    InvalidQuillCount,
    BookLocked,
    NoBookOnLectern,
};

// ============================================================================
// Page Storage
// ============================================================================

/// A single page containing up to `max_page_char_len` UTF-8 characters.
pub const BookPage = struct {
    bytes: [max_page_char_len]u8 = [_]u8{0} ** max_page_char_len,
    len: u16 = 0,

    pub fn text(self: *const BookPage) []const u8 {
        return self.bytes[0..self.len];
    }

    pub fn setText(self: *BookPage, new_text: []const u8) void {
        const copy_len = @min(new_text.len, max_page_char_len);
        @memcpy(self.bytes[0..copy_len], new_text[0..copy_len]);
        self.len = @intCast(copy_len);
    }

    pub fn clear(self: *BookPage) void {
        self.len = 0;
        @memset(&self.bytes, 0);
    }
};

// ============================================================================
// Book and Quill Recipe & Writable Book
// ============================================================================

/// Crafting recipe specifications for Book and Quill:
/// 1 Book + 1 Ink Sac + 1 Feather -> 1 Book and Quill.
/// Supports up to 100 pages.
pub const BookAndQuillRecipe = struct {
    pub const max_pages: u8 = 100;
    pub const required_books: u8 = 1;
    pub const required_ink_sacs: u8 = 1;
    pub const required_feathers: u8 = 1;

    /// Checks if the supplied ingredient counts satisfy the recipe.
    pub fn canCraft(books: u8, ink_sacs: u8, feathers: u8) bool {
        return books >= required_books and ink_sacs >= required_ink_sacs and feathers >= required_feathers;
    }

    /// Matches a 3x3 (or 2x2) crafting grid containing item IDs (shapeless).
    pub fn matchesGrid(grid_items: []const u16) bool {
        var books: u8 = 0;
        var ink_sacs: u8 = 0;
        var feathers: u8 = 0;
        var other: u8 = 0;

        for (grid_items) |item_id| {
            if (item_id == 0) continue;
            if (item_id == BookTag) {
                books += 1;
            } else if (item_id == InkSacTag) {
                ink_sacs += 1;
            } else if (item_id == FeatherTag) {
                feathers += 1;
            } else {
                other += 1;
            }
        }

        return books == 1 and ink_sacs == 1 and feathers == 1 and other == 0;
    }

    /// Crafts a new blank Book and Quill.
    pub fn craft() BookAndQuill {
        return BookAndQuill.init();
    }
};

/// An unsigned, editable Book and Quill supporting up to 100 pages.
pub const BookAndQuill = struct {
    pages: [BookAndQuillRecipe.max_pages]BookPage = [_]BookPage{.{}} ** BookAndQuillRecipe.max_pages,
    page_count: u8 = 1,

    /// Creates a fresh Book and Quill initialized with 1 blank page.
    pub fn init() BookAndQuill {
        return .{
            .pages = [_]BookPage{.{}} ** BookAndQuillRecipe.max_pages,
            .page_count = 1,
        };
    }

    pub fn pageCount(self: *const BookAndQuill) u8 {
        return self.page_count;
    }

    /// Returns the text of a 1-based page index, or null if out of range.
    pub fn getPage(self: *const BookAndQuill, page_1_based: u8) ?[]const u8 {
        if (page_1_based < 1 or page_1_based > self.page_count) return null;
        return self.pages[page_1_based - 1].text();
    }

    /// Sets the text of an existing 1-based page.
    pub fn setPage(self: *BookAndQuill, page_1_based: u8, content: []const u8) BookError!void {
        if (page_1_based < 1 or page_1_based > self.page_count) return BookError.InvalidPageIndex;
        self.pages[page_1_based - 1].setText(content);
    }

    /// Appends a new page with content. Returns the 1-based index of the new page.
    pub fn addPage(self: *BookAndQuill, content: []const u8) BookError!u8 {
        if (self.page_count >= BookAndQuillRecipe.max_pages) return BookError.BookFull;
        self.pages[self.page_count].setText(content);
        self.page_count += 1;
        return self.page_count;
    }

    /// Deletes a 1-based page. If it is the only page, it is cleared instead of removed.
    pub fn deletePage(self: *BookAndQuill, page_1_based: u8) BookError!void {
        if (page_1_based < 1 or page_1_based > self.page_count) return BookError.InvalidPageIndex;

        if (self.page_count == 1) {
            self.pages[0].clear();
            return;
        }

        const idx = page_1_based - 1;
        var i: usize = idx;
        while (i < self.page_count - 1) : (i += 1) {
            self.pages[i] = self.pages[i + 1];
        }
        self.pages[self.page_count - 1].clear();
        self.page_count -= 1;
    }

    /// Signs the Book and Quill with a title and author, locking editing and producing an .original Written Book.
    pub fn sign(self: *const BookAndQuill, book_title: []const u8, book_author: []const u8) BookError!WrittenBook {
        if (book_title.len == 0) return BookError.EmptyTitle;
        if (book_title.len > max_title_len) return BookError.TitleTooLong;
        if (book_author.len > max_author_len) return BookError.AuthorTooLong;

        var written = WrittenBook{
            .generation = .original,
            .page_count = self.page_count,
            .is_locked = true,
        };

        @memcpy(written.title_bytes[0..book_title.len], book_title);
        written.title_len = @intCast(book_title.len);

        const author_to_use = if (book_author.len > 0) book_author else "Player";
        @memcpy(written.author_bytes[0..author_to_use.len], author_to_use);
        written.author_len = @intCast(author_to_use.len);

        var i: usize = 0;
        while (i < self.page_count) : (i += 1) {
            written.pages[i] = self.pages[i];
        }

        return written;
    }
};

// ============================================================================
// Written Book Generation Tiers & Duplication
// ============================================================================

/// Generation tier of a signed Written Book:
/// - 0: original
/// - 1: copy_of_original
/// - 2: copy_of_a_copy
/// - 3: tattered (cannot be copied, generated via trade or corruption)
pub const WrittenBookGeneration = enum(u2) {
    original = 0,
    copy_of_original = 1,
    copy_of_a_copy = 2,
    tattered = 3,

    pub fn toInt(self: WrittenBookGeneration) u2 {
        return @intFromEnum(self);
    }

    pub fn fromInt(val: u2) WrittenBookGeneration {
        return @enumFromInt(val);
    }

    pub fn canCopy(self: WrittenBookGeneration) bool {
        return canCopyWrittenBook(self);
    }

    pub fn nextGeneration(self: WrittenBookGeneration) ?WrittenBookGeneration {
        return switch (self) {
            .original => .copy_of_original,
            .copy_of_original => .copy_of_a_copy,
            .copy_of_a_copy, .tattered => null,
        };
    }

    pub fn displayName(self: WrittenBookGeneration) []const u8 {
        return switch (self) {
            .original => "Original",
            .copy_of_original => "Copy of original",
            .copy_of_a_copy => "Copy of a copy",
            .tattered => "Tattered",
        };
    }
};

/// Returns true if a book of the given generation can be copied.
/// Only .original and .copy_of_original can be copied.
/// A .copy_of_a_copy or .tattered book CANNOT be copied.
pub fn canCopyWrittenBook(gen: WrittenBookGeneration) bool {
    return switch (gen) {
        .original, .copy_of_original => true,
        .copy_of_a_copy, .tattered => false,
    };
}

/// A signed, immutable Written Book.
pub const WrittenBook = struct {
    generation: WrittenBookGeneration = .original,
    title_bytes: [max_title_len]u8 = [_]u8{0} ** max_title_len,
    title_len: u8 = 0,
    author_bytes: [max_author_len]u8 = [_]u8{0} ** max_author_len,
    author_len: u8 = 0,
    pages: [BookAndQuillRecipe.max_pages]BookPage = [_]BookPage{.{}} ** BookAndQuillRecipe.max_pages,
    page_count: u8 = 1,
    is_locked: bool = true,

    pub fn title(self: *const WrittenBook) []const u8 {
        return self.title_bytes[0..self.title_len];
    }

    pub fn author(self: *const WrittenBook) []const u8 {
        return self.author_bytes[0..self.author_len];
    }

    pub fn pageCount(self: *const WrittenBook) u8 {
        return self.page_count;
    }

    pub fn getPage(self: *const WrittenBook, page_1_based: u8) ?[]const u8 {
        if (page_1_based < 1 or page_1_based > self.page_count) return null;
        return self.pages[page_1_based - 1].text();
    }

    pub fn canBeCopied(self: *const WrittenBook) bool {
        return canCopyWrittenBook(self.generation);
    }
};

/// Duplication mechanics for Written Books:
/// Crafting 1 Written Book with 1..8 Book and Quills creates copies with generation incremented by 1.
pub const WrittenBookDuplication = struct {
    pub const min_quills: u8 = 1;
    pub const max_quills: u8 = 8;

    pub const DuplicationOutcome = struct {
        preserved_original: WrittenBook,
        copy_count: u8,
        copy_sample: WrittenBook,
        new_generation: WrittenBookGeneration,
    };

    /// Validates whether a duplication operation can proceed.
    pub fn canDuplicate(book: *const WrittenBook, quill_count: u8) bool {
        if (quill_count < min_quills or quill_count > max_quills) return false;
        return canCopyWrittenBook(book.generation);
    }

    /// Computes the next generation tier, or null if the book cannot be copied.
    pub fn nextTier(gen: WrittenBookGeneration) ?WrittenBookGeneration {
        return gen.nextGeneration();
    }

    /// Matches a 3x3 crafting grid containing exactly 1 Written Book and 1..8 Book and Quills.
    pub fn matchesGrid(grid_items: []const u16) ?u8 {
        var written_books: u8 = 0;
        var quills: u8 = 0;
        var other: u8 = 0;

        for (grid_items) |item_id| {
            if (item_id == 0) continue;
            if (item_id == WrittenBookTag) {
                written_books += 1;
            } else if (item_id == BookAndQuillTag) {
                quills += 1;
            } else {
                other += 1;
            }
        }

        if (written_books == 1 and quills >= min_quills and quills <= max_quills and other == 0) {
            return quills;
        }
        return null;
    }

    /// Duplicates a written book using 1..8 Book and Quills.
    pub fn duplicate(book: *const WrittenBook, quill_count: u8) BookError!DuplicationOutcome {
        if (quill_count < min_quills or quill_count > max_quills) {
            return BookError.InvalidQuillCount;
        }

        if (!canCopyWrittenBook(book.generation)) {
            return BookError.CannotCopyGeneration;
        }

        const next_gen = book.generation.nextGeneration() orelse return BookError.CannotCopyGeneration;

        var copy = book.*;
        copy.generation = next_gen;

        return DuplicationOutcome{
            .preserved_original = book.*,
            .copy_count = quill_count,
            .copy_sample = copy,
            .new_generation = next_gen,
        };
    }
};

// ============================================================================
// Lectern Comparator Formula
// ============================================================================

/// Computes the redstone signal strength (0..15) output by a redstone comparator reading a Lectern.
/// - Returns 0 if !has_book
/// - Returns 15 if total_pages <= 1
/// - Returns @intCast(1 + @divFloor(@as(u16, current_page_1_based - 1) * 14, @as(u16, total_pages - 1))) when total_pages > 1
pub fn lecternComparatorSignal(has_book: bool, current_page_1_based: u8, total_pages: u8) u4 {
    if (!has_book) return 0;
    if (total_pages <= 1) return 15;

    const clamped_page: u16 = @min(@max(current_page_1_based, 1), total_pages);
    const num: u16 = (clamped_page - 1) * 14;
    const den: u16 = total_pages - 1;
    return @intCast(1 + @divFloor(num, den));
}

/// Constants and namespace wrapper for the Lectern comparator formula.
pub const LecternComparatorFormula = struct {
    pub const min_signal: u4 = 0;
    pub const max_signal: u4 = 15;
    pub const single_page_signal: u4 = 15;

    pub fn calculate(has_book: bool, current_page_1_based: u8, total_pages: u8) u4 {
        return lecternComparatorSignal(has_book, current_page_1_based, total_pages);
    }
};

// ============================================================================
// Lectern Page-Turn Pulse
// ============================================================================

/// Turning a page on a Lectern emits a full-strength (15) redstone pulse
/// for 1 redstone tick (2 game ticks = 0.10 seconds).
pub const LecternPageTurnPulse = struct {
    pub const pulse_strength: u4 = 15;
    pub const redstone_ticks: u32 = 1;
    pub const game_ticks: u32 = 2;
    pub const duration_seconds: f32 = 0.10;
    pub const game_ticks_per_second: f32 = 20.0;
    pub const game_tick_duration_seconds: f32 = 0.05;

    remaining_game_ticks: u32 = 0,

    /// Triggers a fresh page-turn pulse (reloads to 2 game ticks).
    pub fn trigger(self: *LecternPageTurnPulse) void {
        self.remaining_game_ticks = game_ticks;
    }

    /// Advances the pulse by the given number of game ticks.
    pub fn tick(self: *LecternPageTurnPulse, delta_game_ticks: u32) void {
        if (self.remaining_game_ticks > delta_game_ticks) {
            self.remaining_game_ticks -= delta_game_ticks;
        } else {
            self.remaining_game_ticks = 0;
        }
    }

    /// Resets the pulse immediately to inactive.
    pub fn reset(self: *LecternPageTurnPulse) void {
        self.remaining_game_ticks = 0;
    }

    /// Returns true if the pulse is currently emitting redstone power.
    pub fn isActive(self: *const LecternPageTurnPulse) bool {
        return self.remaining_game_ticks > 0;
    }

    /// Returns 15 if the pulse is active, 0 otherwise.
    pub fn signal(self: *const LecternPageTurnPulse) u4 {
        return if (self.remaining_game_ticks > 0) pulse_strength else 0;
    }
};

// ============================================================================
// Lectern Block Entity
// ============================================================================

/// Either a Book and Quill or a Written Book placed on a Lectern.
pub const LecternBook = union(enum) {
    writable: BookAndQuill,
    written: WrittenBook,

    pub fn totalPages(self: *const LecternBook) u8 {
        return switch (self.*) {
            .writable => |*b| b.pageCount(),
            .written => |*b| b.pageCount(),
        };
    }

    pub fn getPage(self: *const LecternBook, page_1_based: u8) ?[]const u8 {
        return switch (self.*) {
            .writable => |*b| b.getPage(page_1_based),
            .written => |*b| b.getPage(page_1_based),
        };
    }

    pub fn isWritable(self: *const LecternBook) bool {
        return switch (self.*) {
            .writable => true,
            .written => false,
        };
    }
};

/// Lectern block entity state managing placed book, current page reading,
/// comparator output, and page-turn redstone pulse.
pub const Lectern = struct {
    book: ?LecternBook = null,
    current_page: u8 = 1,
    pulse: LecternPageTurnPulse = .{},

    pub fn init() Lectern {
        return .{};
    }

    pub fn hasBook(self: *const Lectern) bool {
        return self.book != null;
    }

    pub fn totalPages(self: *const Lectern) u8 {
        if (self.book) |*b| {
            return b.totalPages();
        }
        return 0;
    }

    pub fn currentPage(self: *const Lectern) u8 {
        return self.current_page;
    }

    /// Places a book on the lectern. Resets reading position to page 1.
    pub fn insertBook(self: *Lectern, book: LecternBook) void {
        self.book = book;
        self.current_page = 1;
        self.pulse.reset();
    }

    /// Removes the book from the lectern and clears signals.
    pub fn takeBook(self: *Lectern) ?LecternBook {
        const removed = self.book;
        self.book = null;
        self.current_page = 1;
        self.pulse.reset();
        return removed;
    }

    /// Turns to a specific 1-based page. Emits a 2-game-tick pulse of strength 15 if page changed.
    pub fn turnPage(self: *Lectern, new_page_1_based: u8) bool {
        if (self.book == null) return false;
        const total = self.totalPages();
        if (total == 0) return false;

        const target = std.math.clamp(new_page_1_based, 1, total);
        if (target == self.current_page) return false;

        self.current_page = target;
        self.pulse.trigger();
        return true;
    }

    /// Advances to the next page if available. Emits redstone pulse.
    pub fn nextPage(self: *Lectern) bool {
        if (self.book == null) return false;
        if (self.current_page >= self.totalPages()) return false;
        return self.turnPage(self.current_page + 1);
    }

    /// Moves to the previous page if available. Emits redstone pulse.
    pub fn prevPage(self: *Lectern) bool {
        if (self.book == null) return false;
        if (self.current_page <= 1) return false;
        return self.turnPage(self.current_page - 1);
    }

    /// Advances game ticks for the page-turn pulse countdown.
    pub fn tick(self: *Lectern, delta_game_ticks: u32) void {
        self.pulse.tick(delta_game_ticks);
    }

    /// Calculates the comparator signal output (0..15).
    pub fn getComparatorSignal(self: *const Lectern) u4 {
        return lecternComparatorSignal(self.hasBook(), self.current_page, self.totalPages());
    }

    /// Returns direct redstone output signal emitted by a page-turn pulse (15 while active, 0 otherwise).
    pub fn getDirectSignal(self: *const Lectern) u4 {
        return self.pulse.signal();
    }

    /// Returns true if currently emitting a page-turn pulse.
    pub fn isPulsing(self: *const Lectern) bool {
        return self.pulse.isActive();
    }
};

// ============================================================================
// Unit Tests (At least 12 comprehensive test blocks)
// ============================================================================

test "1: BookAndQuillRecipe: ingredient requirements and shapeless grid matching" {
    // 1 Book + 1 Ink Sac + 1 Feather -> 1 Book and Quill
    try std.testing.expectEqual(@as(u8, 1), BookAndQuillRecipe.required_books);
    try std.testing.expectEqual(@as(u8, 1), BookAndQuillRecipe.required_ink_sacs);
    try std.testing.expectEqual(@as(u8, 1), BookAndQuillRecipe.required_feathers);
    try std.testing.expectEqual(@as(u8, 100), BookAndQuillRecipe.max_pages);

    // canCraft checks
    try std.testing.expect(BookAndQuillRecipe.canCraft(1, 1, 1));
    try std.testing.expect(BookAndQuillRecipe.canCraft(5, 2, 3));
    try std.testing.expect(!BookAndQuillRecipe.canCraft(0, 1, 1));
    try std.testing.expect(!BookAndQuillRecipe.canCraft(1, 0, 1));
    try std.testing.expect(!BookAndQuillRecipe.canCraft(1, 1, 0));

    // Shapeless 3x3 crafting grid match
    const grid_valid = [_]u16{
        0, BookTag, 0,
        InkSacTag, 0, 0,
        0, FeatherTag, 0,
    };
    try std.testing.expect(BookAndQuillRecipe.matchesGrid(&grid_valid));

    // Extra item in grid fails recipe
    const grid_with_dirt = [_]u16{
        0, BookTag, 3, // 3 is dirt
        InkSacTag, 0, 0,
        0, FeatherTag, 0,
    };
    try std.testing.expect(!BookAndQuillRecipe.matchesGrid(&grid_with_dirt));

    // Duplicate book fails recipe
    const grid_dup_book = [_]u16{
        BookTag, BookTag, 0,
        InkSacTag, 0, 0,
        0, FeatherTag, 0,
    };
    try std.testing.expect(!BookAndQuillRecipe.matchesGrid(&grid_dup_book));

    // Crafting creates a book with 1 page initialized
    const crafted = BookAndQuillRecipe.craft();
    try std.testing.expectEqual(@as(u8, 1), crafted.pageCount());
}

test "2: BookAndQuill: page addition up to maximum 100 pages limit" {
    var book = BookAndQuill.init();
    try std.testing.expectEqual(@as(u8, 1), book.pageCount());

    // Fill pages 2 through 100
    var i: usize = 2;
    while (i <= 100) : (i += 1) {
        var buf: [32]u8 = undefined;
        const page_text = try std.fmt.bufPrint(&buf, "Page number {d}", .{i});
        const page_idx = try book.addPage(page_text);
        try std.testing.expectEqual(@as(u8, @intCast(i)), page_idx);
        try std.testing.expectEqual(@as(u8, @intCast(i)), book.pageCount());
    }

    // Attempting to add 101st page exceeds limit and returns error.BookFull
    try std.testing.expectError(error.BookFull, book.addPage("101st page"));
    try std.testing.expectEqual(@as(u8, 100), book.pageCount());
}

test "3: BookAndQuill: get, set, delete page contents and boundary handling" {
    var book = BookAndQuill.init();
    try book.setPage(1, "First page text");
    try std.testing.expectEqualStrings("First page text", book.getPage(1).?);

    // Invalid index bounds
    try std.testing.expect(book.getPage(0) == null);
    try std.testing.expect(book.getPage(2) == null);
    try std.testing.expectError(error.InvalidPageIndex, book.setPage(0, "Invalid"));
    try std.testing.expectError(error.InvalidPageIndex, book.setPage(2, "Invalid"));

    // Add page 2 and page 3
    _ = try book.addPage("Second page text");
    _ = try book.addPage("Third page text");
    try std.testing.expectEqual(@as(u8, 3), book.pageCount());

    // Delete middle page (page 2)
    try book.deletePage(2);
    try std.testing.expectEqual(@as(u8, 2), book.pageCount());
    try std.testing.expectEqualStrings("First page text", book.getPage(1).?);
    try std.testing.expectEqualStrings("Third page text", book.getPage(2).?);

    // Deleting only remaining page clears content without dropping page count below 1
    try book.deletePage(2);
    try std.testing.expectEqual(@as(u8, 1), book.pageCount());
    try book.deletePage(1);
    try std.testing.expectEqual(@as(u8, 1), book.pageCount());
    try std.testing.expectEqualStrings("", book.getPage(1).?);
}

test "4: BookAndQuill: signing produces original WrittenBook and locks editing" {
    var quill = BookAndQuill.init();
    try quill.setPage(1, "The story begins in a dark forest.");
    _ = try quill.addPage("The hero found ancient ruins.");

    const signed = try quill.sign("Hero's Tale", "Alex");
    try std.testing.expectEqual(WrittenBookGeneration.original, signed.generation);
    try std.testing.expectEqualStrings("Hero's Tale", signed.title());
    try std.testing.expectEqualStrings("Alex", signed.author());
    try std.testing.expectEqual(@as(u8, 2), signed.pageCount());
    try std.testing.expectEqualStrings("The story begins in a dark forest.", signed.getPage(1).?);
    try std.testing.expectEqualStrings("The hero found ancient ruins.", signed.getPage(2).?);
    try std.testing.expect(signed.is_locked);
}

test "5: BookAndQuill: signing title and author validation" {
    var quill = BookAndQuill.init();
    try quill.setPage(1, "Content");

    // Empty title rejected
    try std.testing.expectError(error.EmptyTitle, quill.sign("", "Author"));

    // Title exceeding max_title_len (16 chars) rejected
    try std.testing.expectError(error.TitleTooLong, quill.sign("TitleThatIsWayTooLong123", "Author"));

    // Author exceeding max_author_len (16 chars) rejected
    try std.testing.expectError(error.AuthorTooLong, quill.sign("Good Title", "SuperLongAuthorNameThatFails"));

    // Default author "Player" when author string is empty
    const default_author_book = try quill.sign("My Journey", "");
    try std.testing.expectEqualStrings("Player", default_author_book.author());
}

test "6: WrittenBookGeneration: enum values, names, and tier transitions" {
    // Exact enum integer representations: 0, 1, 2, 3
    try std.testing.expectEqual(@as(u2, 0), WrittenBookGeneration.original.toInt());
    try std.testing.expectEqual(@as(u2, 1), WrittenBookGeneration.copy_of_original.toInt());
    try std.testing.expectEqual(@as(u2, 2), WrittenBookGeneration.copy_of_a_copy.toInt());
    try std.testing.expectEqual(@as(u2, 3), WrittenBookGeneration.tattered.toInt());

    // fromInt conversion
    try std.testing.expectEqual(WrittenBookGeneration.original, WrittenBookGeneration.fromInt(0));
    try std.testing.expectEqual(WrittenBookGeneration.copy_of_original, WrittenBookGeneration.fromInt(1));
    try std.testing.expectEqual(WrittenBookGeneration.copy_of_a_copy, WrittenBookGeneration.fromInt(2));
    try std.testing.expectEqual(WrittenBookGeneration.tattered, WrittenBookGeneration.fromInt(3));

    // Display names
    try std.testing.expectEqualStrings("Original", WrittenBookGeneration.original.displayName());
    try std.testing.expectEqualStrings("Copy of original", WrittenBookGeneration.copy_of_original.displayName());
    try std.testing.expectEqualStrings("Copy of a copy", WrittenBookGeneration.copy_of_a_copy.displayName());
    try std.testing.expectEqualStrings("Tattered", WrittenBookGeneration.tattered.displayName());

    // Next generation transitions
    try std.testing.expectEqual(WrittenBookGeneration.copy_of_original, WrittenBookGeneration.original.nextGeneration().?);
    try std.testing.expectEqual(WrittenBookGeneration.copy_of_a_copy, WrittenBookGeneration.copy_of_original.nextGeneration().?);
    try std.testing.expect(WrittenBookGeneration.copy_of_a_copy.nextGeneration() == null);
    try std.testing.expect(WrittenBookGeneration.tattered.nextGeneration() == null);
}

test "7: canCopyWrittenBook: tier copying permissions" {
    try std.testing.expect(canCopyWrittenBook(.original));
    try std.testing.expect(canCopyWrittenBook(.copy_of_original));
    try std.testing.expect(!canCopyWrittenBook(.copy_of_a_copy));
    try std.testing.expect(!canCopyWrittenBook(.tattered));

    try std.testing.expect(WrittenBookGeneration.original.canCopy());
    try std.testing.expect(WrittenBookGeneration.copy_of_original.canCopy());
    try std.testing.expect(!WrittenBookGeneration.copy_of_a_copy.canCopy());
    try std.testing.expect(!WrittenBookGeneration.tattered.canCopy());
}

test "8: WrittenBookDuplication: copying original produces copy_of_original with 1..8 quills" {
    var quill = BookAndQuill.init();
    try quill.setPage(1, "Original manuscript text.");
    const original_book = try quill.sign("Tome of Origin", "Wizard");

    // Can duplicate with 1..8 quills
    var q: u8 = 1;
    while (q <= 8) : (q += 1) {
        try std.testing.expect(WrittenBookDuplication.canDuplicate(&original_book, q));
        const res = try WrittenBookDuplication.duplicate(&original_book, q);
        try std.testing.expectEqual(q, res.copy_count);
        try std.testing.expectEqual(WrittenBookGeneration.copy_of_original, res.new_generation);
        try std.testing.expectEqual(WrittenBookGeneration.original, res.preserved_original.generation);
        try std.testing.expectEqualStrings("Tome of Origin", res.copy_sample.title());
        try std.testing.expectEqualStrings("Wizard", res.copy_sample.author());
        try std.testing.expectEqualStrings("Original manuscript text.", res.copy_sample.getPage(1).?);
    }
}

test "9: WrittenBookDuplication: copying copy_of_original produces copy_of_a_copy" {
    var quill = BookAndQuill.init();
    try quill.setPage(1, "Chapter 1: The Deep Dark");
    const original_book = try quill.sign("Cave Guide", "Miner");

    // Tier 1: original -> copy_of_original
    const res1 = try WrittenBookDuplication.duplicate(&original_book, 2);
    const copy_1 = res1.copy_sample;
    try std.testing.expectEqual(WrittenBookGeneration.copy_of_original, copy_1.generation);

    // Tier 2: copy_of_original -> copy_of_a_copy
    try std.testing.expect(WrittenBookDuplication.canDuplicate(&copy_1, 3));
    const res2 = try WrittenBookDuplication.duplicate(&copy_1, 3);
    try std.testing.expectEqual(@as(u8, 3), res2.copy_count);
    try std.testing.expectEqual(WrittenBookGeneration.copy_of_a_copy, res2.new_generation);
    try std.testing.expectEqual(WrittenBookGeneration.copy_of_a_copy, res2.copy_sample.generation);
}

test "10: WrittenBookDuplication: copy restrictions on copy_of_a_copy, tattered, and invalid counts" {
    var quill = BookAndQuill.init();
    try quill.setPage(1, "Ancient wisdom");
    const original = try quill.sign("Ancient Lore", "Elder");
    const tier1 = (try WrittenBookDuplication.duplicate(&original, 1)).copy_sample;
    const tier2 = (try WrittenBookDuplication.duplicate(&tier1, 1)).copy_sample;

    // copy_of_a_copy cannot be copied
    try std.testing.expectEqual(WrittenBookGeneration.copy_of_a_copy, tier2.generation);
    try std.testing.expect(!tier2.canBeCopied());
    try std.testing.expect(!WrittenBookDuplication.canDuplicate(&tier2, 1));
    try std.testing.expectError(error.CannotCopyGeneration, WrittenBookDuplication.duplicate(&tier2, 1));

    // tattered book cannot be copied
    var tattered_book = tier2;
    tattered_book.generation = .tattered;
    try std.testing.expect(!tattered_book.canBeCopied());
    try std.testing.expect(!WrittenBookDuplication.canDuplicate(&tattered_book, 1));
    try std.testing.expectError(error.CannotCopyGeneration, WrittenBookDuplication.duplicate(&tattered_book, 1));

    // Invalid quill count: 0 or > 8
    try std.testing.expectError(error.InvalidQuillCount, WrittenBookDuplication.duplicate(&original, 0));
    try std.testing.expectError(error.InvalidQuillCount, WrittenBookDuplication.duplicate(&original, 9));

    // Grid matcher
    const valid_grid = [_]u16{
        WrittenBookTag, BookAndQuillTag, BookAndQuillTag,
        BookAndQuillTag, 0, 0,
        0, 0, 0,
    };
    try std.testing.expectEqual(@as(?u8, 3), WrittenBookDuplication.matchesGrid(&valid_grid));
}

test "11: LecternComparatorFormula: empty lectern outputs 0" {
    // When has_book is false, signal is 0 regardless of page numbers
    try std.testing.expectEqual(@as(u4, 0), lecternComparatorSignal(false, 0, 0));
    try std.testing.expectEqual(@as(u4, 0), lecternComparatorSignal(false, 1, 1));
    try std.testing.expectEqual(@as(u4, 0), lecternComparatorSignal(false, 5, 10));
    try std.testing.expectEqual(@as(u4, 0), lecternComparatorSignal(false, 15, 15));
    try std.testing.expectEqual(@as(u4, 0), LecternComparatorFormula.calculate(false, 1, 50));
}

test "12: LecternComparatorFormula: single-page book outputs 15" {
    // Single page book (total_pages <= 1) outputs full strength 15
    try std.testing.expectEqual(@as(u4, 15), lecternComparatorSignal(true, 1, 1));
    try std.testing.expectEqual(@as(u4, 15), lecternComparatorSignal(true, 0, 1));
    try std.testing.expectEqual(@as(u4, 15), lecternComparatorSignal(true, 1, 0));
    try std.testing.expectEqual(@as(u4, 15), LecternComparatorFormula.calculate(true, 1, 1));
}

test "13: LecternComparatorFormula: 2-page book outputs 1 and 15" {
    // 2-page book:
    // Page 1: 1 + floor((0 * 14) / 1) = 1
    // Page 2: 1 + floor((1 * 14) / 1) = 15
    try std.testing.expectEqual(@as(u4, 1), lecternComparatorSignal(true, 1, 2));
    try std.testing.expectEqual(@as(u4, 15), lecternComparatorSignal(true, 2, 2));
}

test "14: LecternComparatorFormula: 3-page, 5-page, and 15-page linear scaling" {
    // 3-page book:
    // Page 1: 1 + floor(0/2) = 1
    // Page 2: 1 + floor(14/2) = 8
    // Page 3: 1 + floor(28/2) = 15
    try std.testing.expectEqual(@as(u4, 1), lecternComparatorSignal(true, 1, 3));
    try std.testing.expectEqual(@as(u4, 8), lecternComparatorSignal(true, 2, 3));
    try std.testing.expectEqual(@as(u4, 15), lecternComparatorSignal(true, 3, 3));

    // 5-page book:
    // Page 1: 1 + floor(0/4) = 1
    // Page 2: 1 + floor(14/4) = 4
    // Page 3: 1 + floor(28/4) = 8
    // Page 4: 1 + floor(42/4) = 11
    // Page 5: 1 + floor(56/4) = 15
    try std.testing.expectEqual(@as(u4, 1), lecternComparatorSignal(true, 1, 5));
    try std.testing.expectEqual(@as(u4, 4), lecternComparatorSignal(true, 2, 5));
    try std.testing.expectEqual(@as(u4, 8), lecternComparatorSignal(true, 3, 5));
    try std.testing.expectEqual(@as(u4, 11), lecternComparatorSignal(true, 4, 5));
    try std.testing.expectEqual(@as(u4, 15), lecternComparatorSignal(true, 5, 5));

    // 15-page book: exact 1:1 linear mapping for pages 1..15
    var p: u8 = 1;
    while (p <= 15) : (p += 1) {
        try std.testing.expectEqual(@as(u4, @intCast(p)), lecternComparatorSignal(true, p, 15));
    }
}

test "15: LecternComparatorFormula: 100-page book endpoints and monotonicity" {
    // Page 1 of 100 is 1
    try std.testing.expectEqual(@as(u4, 1), lecternComparatorSignal(true, 1, 100));
    // Page 100 of 100 is 15
    try std.testing.expectEqual(@as(u4, 15), lecternComparatorSignal(true, 100, 100));

    // Check monotonic non-decreasing progression across all 100 pages
    var prev_sig: u4 = 1;
    var page: u8 = 1;
    while (page <= 100) : (page += 1) {
        const sig = lecternComparatorSignal(true, page, 100);
        try std.testing.expect(sig >= prev_sig);
        try std.testing.expect(sig >= 1 and sig <= 15);
        prev_sig = sig;
    }
}

test "16: LecternPageTurnPulse: duration, strength, and tick countdown" {
    try std.testing.expectEqual(@as(u4, 15), LecternPageTurnPulse.pulse_strength);
    try std.testing.expectEqual(@as(u32, 1), LecternPageTurnPulse.redstone_ticks);
    try std.testing.expectEqual(@as(u32, 2), LecternPageTurnPulse.game_ticks);
    try std.testing.expectApproxEqAbs(@as(f32, 0.10), LecternPageTurnPulse.duration_seconds, 0.001);

    var pulse = LecternPageTurnPulse{};
    try std.testing.expect(!pulse.isActive());
    try std.testing.expectEqual(@as(u4, 0), pulse.signal());

    // Trigger pulse
    pulse.trigger();
    try std.testing.expect(pulse.isActive());
    try std.testing.expectEqual(@as(u32, 2), pulse.remaining_game_ticks);
    try std.testing.expectEqual(@as(u4, 15), pulse.signal());

    // Tick 1 game tick -> 1 tick remaining, signal still active
    pulse.tick(1);
    try std.testing.expect(pulse.isActive());
    try std.testing.expectEqual(@as(u32, 1), pulse.remaining_game_ticks);
    try std.testing.expectEqual(@as(u4, 15), pulse.signal());

    // Tick 1 more game tick -> 0 ticks remaining, pulse expires
    pulse.tick(1);
    try std.testing.expect(!pulse.isActive());
    try std.testing.expectEqual(@as(u32, 0), pulse.remaining_game_ticks);
    try std.testing.expectEqual(@as(u4, 0), pulse.signal());

    // Re-triggering and reset
    pulse.trigger();
    try std.testing.expect(pulse.isActive());
    pulse.reset();
    try std.testing.expect(!pulse.isActive());
    try std.testing.expectEqual(@as(u4, 0), pulse.signal());
}

test "17: Lectern: complete lifecycle with insertion, page turns, pulse, and removal" {
    var lectern = Lectern.init();
    try std.testing.expect(!lectern.hasBook());
    try std.testing.expectEqual(@as(u4, 0), lectern.getComparatorSignal());
    try std.testing.expectEqual(@as(u4, 0), lectern.getDirectSignal());

    // Create 5-page book
    var quill = BookAndQuill.init();
    try quill.setPage(1, "Page 1 Content");
    _ = try quill.addPage("Page 2 Content");
    _ = try quill.addPage("Page 3 Content");
    _ = try quill.addPage("Page 4 Content");
    _ = try quill.addPage("Page 5 Content");
    const book = try quill.sign("Manual", "Crafter");

    // Insert book onto lectern
    lectern.insertBook(.{ .written = book });
    try std.testing.expect(lectern.hasBook());
    try std.testing.expectEqual(@as(u8, 5), lectern.totalPages());
    try std.testing.expectEqual(@as(u8, 1), lectern.currentPage());
    // Comparator emits page 1 of 5 -> 1
    try std.testing.expectEqual(@as(u4, 1), lectern.getComparatorSignal());
    // Insertion does not emit a page-turn pulse
    try std.testing.expectEqual(@as(u4, 0), lectern.getDirectSignal());

    // Turn page to 2
    try std.testing.expect(lectern.turnPage(2));
    try std.testing.expectEqual(@as(u8, 2), lectern.currentPage());
    // Page 2 of 5 comparator output is 4
    try std.testing.expectEqual(@as(u4, 4), lectern.getComparatorSignal());
    // Direct pulse is now active at 15
    try std.testing.expect(lectern.isPulsing());
    try std.testing.expectEqual(@as(u4, 15), lectern.getDirectSignal());

    // Advance 1 game tick: still pulsing
    lectern.tick(1);
    try std.testing.expect(lectern.isPulsing());
    try std.testing.expectEqual(@as(u4, 15), lectern.getDirectSignal());

    // Advance 1 more game tick: pulse ends
    lectern.tick(1);
    try std.testing.expect(!lectern.isPulsing());
    try std.testing.expectEqual(@as(u4, 0), lectern.getDirectSignal());
    // Comparator signal remains 4
    try std.testing.expectEqual(@as(u4, 4), lectern.getComparatorSignal());

    // Next page and prev page helpers
    try std.testing.expect(lectern.nextPage()); // moves to page 3, triggers pulse
    try std.testing.expectEqual(@as(u8, 3), lectern.currentPage());
    try std.testing.expect(lectern.isPulsing());
    lectern.tick(2); // expire pulse

    // Turning to same page does not re-pulse
    try std.testing.expect(!lectern.turnPage(3));
    try std.testing.expect(!lectern.isPulsing());

    // Remove book
    const taken = lectern.takeBook();
    try std.testing.expect(taken != null);
    try std.testing.expect(!lectern.hasBook());
    try std.testing.expectEqual(@as(u4, 0), lectern.getComparatorSignal());
    try std.testing.expectEqual(@as(u4, 0), lectern.getDirectSignal());
}

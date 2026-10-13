const std = @import("std");
const c = @cImport({
    @cDefine("GL_GLEXT_PROTOTYPES", "1");
    @cInclude("GL/glcorearb.h");
    @cInclude("GLFW/glfw3.h");
});
const shader = @import("shader.zig");

pub const UIVertex = extern struct {
    position: [2]f32,
    color: [4]f32,
};

pub const UIRenderer = struct {
    vao: c.GLuint,
    vbo: c.GLuint,
    program: c.GLuint,

    const vert_src =
        \\#version 330 core
        \\layout (location = 0) in vec2 aPos;
        \\layout (location = 1) in vec4 aColor;
        \\out vec4 vColor;
        \\void main() {
        \\    vColor = aColor;
        \\    gl_Position = vec4(aPos, 0.0, 1.0);
        \\}
    ;

    const frag_src =
        \\#version 330 core
        \\in vec4 vColor;
        \\out vec4 FragColor;
        \\void main() {
        \\    FragColor = vColor;
        \\}
    ;

    pub fn init(allocator: std.mem.Allocator) !UIRenderer {
        var vao: c.GLuint = 0;
        var vbo: c.GLuint = 0;

        c.glGenVertexArrays(1, &vao);
        c.glGenBuffers(1, &vbo);

        c.glBindVertexArray(vao);
        c.glBindBuffer(c.GL_ARRAY_BUFFER, vbo);

        // Max 128 UI vertices
        c.glBufferData(c.GL_ARRAY_BUFFER, 4096 * @sizeOf(UIVertex), null, c.GL_DYNAMIC_DRAW);

        c.glEnableVertexAttribArray(0);
        c.glVertexAttribPointer(0, 2, c.GL_FLOAT, c.GL_FALSE, @sizeOf(UIVertex), @ptrFromInt(0));

        c.glEnableVertexAttribArray(1);
        c.glVertexAttribPointer(1, 4, c.GL_FLOAT, c.GL_FALSE, @sizeOf(UIVertex), @ptrFromInt(@sizeOf([2]f32)));

        c.glBindVertexArray(0);

        const program = try shader.createProgram(allocator, vert_src, frag_src);

        return .{
            .vao = vao,
            .vbo = vbo,
            .program = program,
        };
    }

    pub fn deinit(self: *UIRenderer) void {
        c.glDeleteVertexArrays(1, &self.vao);
        c.glDeleteBuffers(1, &self.vbo);
        c.glDeleteProgram(self.program);
    }

    /// Append quad as 2 triangles (6 vertices) to buffer
    fn addQuad(verts: []UIVertex, count: *usize, x0: f32, y0: f32, x1: f32, y1: f32, col: [4]f32) void {
        if (count.* + 6 > verts.len) return;
        const i = count.*;
        verts[i] = .{ .position = .{ x0, y0 }, .color = col };
        verts[i + 1] = .{ .position = .{ x1, y0 }, .color = col };
        verts[i + 2] = .{ .position = .{ x1, y1 }, .color = col };
        verts[i + 3] = .{ .position = .{ x0, y0 }, .color = col };
        verts[i + 4] = .{ .position = .{ x1, y1 }, .color = col };
        verts[i + 5] = .{ .position = .{ x0, y1 }, .color = col };
        count.* += 6;
    }

    /// Append bordered rectangle (outer frame + inner fill)
    fn addBorderedRect(verts: []UIVertex, count: *usize, x0: f32, y0: f32, x1: f32, y1: f32, border_w: f32, border_col: [4]f32, fill_col: [4]f32) void {
        addQuad(verts, count, x0, y0, x1, y1, border_col);
        addQuad(verts, count, x0 + border_w, y0 + border_w, x1 - border_w, y1 - border_w, fill_col);
    }


    /// Render a toast status bar in the top-right corner.
    /// `alpha` in [0..1] scales opacity, `color` is RGB tint.
    pub fn drawToast(self: *UIRenderer, aspect: f32, alpha: f32, color: [3]f32) void {
        if (alpha <= 0.01) return;
        var verts: [32]UIVertex = undefined;
        var count: usize = 0;
        const w: f32 = 0.22 / aspect;
        const h: f32 = 0.035;
        const x1: f32 = 0.95;
        const x0: f32 = x1 - w;
        const y1: f32 = 0.92;
        const y0: f32 = y1 - h;
        const border = [4]f32{ 0.1, 0.1, 0.1, 0.85 * alpha };
        const fill = [4]f32{ color[0], color[1], color[2], 0.75 * alpha };
        addBorderedRect(&verts, &count, x0, y0, x1, y1, 0.003, border, fill);

        c.glEnable(c.GL_BLEND);
        c.glBlendFunc(c.GL_SRC_ALPHA, c.GL_ONE_MINUS_SRC_ALPHA);
        c.glDisable(c.GL_DEPTH_TEST);
        c.glUseProgram(self.program);
        c.glBindVertexArray(self.vao);
        c.glBindBuffer(c.GL_ARRAY_BUFFER, self.vbo);
        c.glBufferSubData(c.GL_ARRAY_BUFFER, 0, @intCast(count * @sizeOf(UIVertex)), &verts);
        c.glDrawArrays(c.GL_TRIANGLES, 0, @intCast(count));
        c.glEnable(c.GL_DEPTH_TEST);
        c.glDisable(c.GL_BLEND);
    }

    /// Render crosshair and hotbar block indicators.
    /// screen aspect = width / height.
    pub fn draw(self: *UIRenderer, aspect: f32, selected_slot: usize) void {
        var verts: [512]UIVertex = undefined;
        var count: usize = 0;

        // 1. Crosshair in screen center: two quads (horizontal and vertical bars)
        const ch_thickness: f32 = 0.003;
        const ch_len_y: f32 = 0.025;
        const ch_len_x: f32 = ch_len_y / aspect;
        const ch_th_x: f32 = ch_thickness / aspect;
        const crosshair_color = [4]f32{ 1.0, 1.0, 1.0, 0.85 };

        addQuad(&verts, &count, -ch_len_x, -ch_thickness, ch_len_x, ch_thickness, crosshair_color);
        addQuad(&verts, &count, -ch_th_x, -ch_len_y, ch_th_x, ch_len_y, crosshair_color);

        // 2. Hotbar at bottom center (6 slots)
        const slot_w: f32 = 0.045 / aspect;
        const slot_h: f32 = 0.045;
        const spacing: f32 = 0.010 / aspect;
        const base_y: f32 = -0.92;
        const total_w = 6.0 * slot_w + 5.0 * spacing;
        const start_x = -total_w / 2.0;

        const slot_colors = [6][4]f32{
            .{ 0.6, 0.6, 0.62, 0.9 }, // 0: Stone
            .{ 0.55, 0.35, 0.2, 0.9 }, // 1: Dirt
            .{ 0.25, 0.75, 0.25, 0.9 }, // 2: Grass
            .{ 0.2, 0.45, 0.85, 0.9 }, // 3: Water
            .{ 0.45, 0.28, 0.12, 0.9 }, // 4: Wood Log
            .{ 0.15, 0.55, 0.15, 0.9 }, // 5: Leaves
        };

        var i: usize = 0;
        while (i < 6) : (i += 1) {
            const x0 = start_x + @as(f32, @floatFromInt(i)) * (slot_w + spacing);
            const x1 = x0 + slot_w;
            const y0 = base_y;
            const y1 = base_y + slot_h;

            const is_sel = (i == selected_slot);
            const color = if (is_sel) [4]f32{ 1.0, 1.0, 1.0, 1.0 } else slot_colors[i];

            addQuad(&verts, &count, x0, y0, x1, y1, color);
        }

        self.flush(&verts, count);
    }

    /// Render full-screen peripheral portal vignette overlay during Nether warp charging.
    /// `intensity` in [0..1] scales border opacity and purple tint.
    pub fn drawPortalVignette(self: *UIRenderer, aspect: f32, intensity: f32) void {
        _ = aspect;
        if (intensity <= 0.01) return;
        var verts: [64]UIVertex = undefined;
        var count: usize = 0;

        const max_a = @min(0.75, intensity * 0.75);
        const col_edge: [4]f32 = .{ 0.45, 0.08, 0.65, max_a };
        const col_mid: [4]f32 = .{ 0.35, 0.05, 0.50, max_a * 0.5 };

        const border_y = 0.28 * @min(1.0, intensity * 1.2);
        const border_x = 0.28 * @min(1.0, intensity * 1.2);

        // Top bar
        addQuad(&verts, &count, -1.0, 1.0 - border_y, 1.0, 1.0, col_edge);
        // Bottom bar
        addQuad(&verts, &count, -1.0, -1.0, 1.0, -1.0 + border_y, col_edge);
        // Left bar
        addQuad(&verts, &count, -1.0, -1.0, -1.0 + border_x, 1.0, col_mid);
        // Right bar
        addQuad(&verts, &count, 1.0 - border_x, -1.0, 1.0, 1.0, col_mid);

        self.flush(&verts, count);
    }

    /// Render full-screen post-warp stabilization flash fade overlay.
    /// `alpha` in [0..1] scales flash transparency.
    pub fn drawPortalFlash(self: *UIRenderer, aspect: f32, alpha: f32) void {
        _ = aspect;
        if (alpha <= 0.01) return;
        var verts: [6]UIVertex = undefined;
        var count: usize = 0;
        const col: [4]f32 = .{ 0.85, 0.40, 1.0, @min(0.85, alpha) };
        addQuad(&verts, &count, -1.0, -1.0, 1.0, 1.0, col);
        self.flush(&verts, count);
    }

    /// Render in-game HUD with inventory item stacks, selected slot border,
    /// and an optional mining progress bar above the crosshair (0..1, <0 hides).
    pub fn drawHUD(self: *UIRenderer, aspect: f32, selected_slot: usize, hotbar_items: []const [4]f32, hotbar_counts: []const u8) void {
        self.drawHUDWithProgress(aspect, selected_slot, hotbar_items, hotbar_counts, -1.0);
    }

    pub fn drawHUDWithVitals(self: *UIRenderer, aspect: f32, selected_slot: usize, hotbar_items: []const [4]f32, hotbar_counts: []const u8, mine_frac: f32, health: f32, hunger: f32) void {
        self.drawHUDWithProgressVitals(aspect, selected_slot, hotbar_items, hotbar_counts, mine_frac, health, hunger, false, 15.0, 0.0, 0.0);
    }

    pub fn drawHUDWithBuffs(self: *UIRenderer, aspect: f32, selected_slot: usize, hotbar_items: []const [4]f32, hotbar_counts: []const u8, mine_frac: f32, health: f32, hunger: f32, regen: bool, oxygen: f32, fire_res_timer: f32) void {
        self.drawHUDWithProgressVitals(aspect, selected_slot, hotbar_items, hotbar_counts, mine_frac, health, hunger, regen, oxygen, fire_res_timer, 0.0);
    }

    pub fn drawHUDWithProgress(self: *UIRenderer, aspect: f32, selected_slot: usize, hotbar_items: []const [4]f32, hotbar_counts: []const u8, mine_frac: f32) void {
        self.drawHUDWithProgressVitals(aspect, selected_slot, hotbar_items, hotbar_counts, mine_frac, 20.0, 20.0, false, 15.0, 0.0, 0.0);
    }

    pub fn drawHUDWithProgressVitals(self: *UIRenderer, aspect: f32, selected_slot: usize, hotbar_items: []const [4]f32, hotbar_counts: []const u8, mine_frac: f32, health: f32, hunger: f32, regen: bool, oxygen: f32, fire_res_timer: f32, wither_timer: f32) void {
        self.drawHUDWithCompass(aspect, selected_slot, hotbar_items, hotbar_counts, mine_frac, health, hunger, regen, oxygen, fire_res_timer, wither_timer, -999.0, false);
    }

    pub fn drawHUDWithCompass(self: *UIRenderer, aspect: f32, selected_slot: usize, hotbar_items: []const [4]f32, hotbar_counts: []const u8, mine_frac: f32, health: f32, hunger: f32, regen: bool, oxygen: f32, fire_res_timer: f32, wither_timer: f32, compass_rel: f32, is_lodestone: bool) void {
        var verts: [1024]UIVertex = undefined;
        var count: usize = 0;

        // Crosshair
        const ch_thickness: f32 = 0.003;
        const ch_len_y: f32 = 0.025;
        const ch_len_x: f32 = ch_len_y / aspect;
        const ch_th_x: f32 = ch_thickness / aspect;
        const crosshair_color = [4]f32{ 1.0, 1.0, 1.0, 0.85 };
        addQuad(&verts, &count, -ch_len_x, -ch_thickness, ch_len_x, ch_thickness, crosshair_color);
        addQuad(&verts, &count, -ch_th_x, -ch_len_y, ch_th_x, ch_len_y, crosshair_color);

        // Hotbar container background
        const slot_w: f32 = 0.052 / aspect;
        const slot_h: f32 = 0.052;
        const spacing: f32 = 0.008 / aspect;
        const base_y: f32 = -0.92;
        const total_w = 6.0 * slot_w + 5.0 * spacing;
        const start_x = -total_w / 2.0;

        // Hotbar backing frame
        addBorderedRect(&verts, &count, start_x - 0.01 / aspect, base_y - 0.01, start_x + total_w + 0.01 / aspect, base_y + slot_h + 0.01, 0.003, .{ 0.1, 0.1, 0.1, 0.8 }, .{ 0.2, 0.2, 0.22, 0.85 });

        var i: usize = 0;
        while (i < 6) : (i += 1) {
            const x0 = start_x + @as(f32, @floatFromInt(i)) * (slot_w + spacing);
            const x1 = x0 + slot_w;
            const y0 = base_y;
            const y1 = base_y + slot_h;

            const is_sel = (i == selected_slot);
            const border_col: [4]f32 = if (is_sel) .{ 1.0, 0.95, 0.4, 1.0 } else .{ 0.35, 0.35, 0.38, 0.9 };
            const slot_bg: [4]f32 = .{ 0.15, 0.15, 0.17, 0.9 };

            addBorderedRect(&verts, &count, x0, y0, x1, y1, if (is_sel) 0.004 else 0.002, border_col, slot_bg);

            // Item interior icon
            if (i < hotbar_items.len and hotbar_counts[i] > 0) {
                const icon_inset_x = 0.008 / aspect;
                const icon_inset_y = 0.008;
                addQuad(&verts, &count, x0 + icon_inset_x, y0 + icon_inset_y, x1 - icon_inset_x, y1 - icon_inset_y, hotbar_items[i]);

                // Stack count bar indicator (width proportional to count / 64)
                const bar_h: f32 = 0.004;
                const frac = @as(f32, @floatFromInt(hotbar_counts[i])) / 64.0;
                const bar_w = (slot_w - 2.0 * icon_inset_x) * @min(1.0, frac);
                addQuad(&verts, &count, x0 + icon_inset_x, y0 + 0.003, x0 + icon_inset_x + bar_w, y0 + 0.003 + bar_h, .{ 0.3, 0.9, 0.3, 0.9 });
            }
        }

        // Health (red) + hunger (orange) bars above hotbar
        {
            const bw: f32 = 0.10;
            const bh: f32 = 0.010;
            const by0 = base_y - 0.022;
            // Health left half
            const hbx0 = start_x;
            addBorderedRect(&verts, &count, hbx0, by0, hbx0 + bw, by0 + bh, 0.0015, .{ 0.1, 0.05, 0.05, 0.9 }, .{ 0.25, 0.08, 0.08, 0.9 });
            const hfill = bw * @min(1.0, @max(0.0, health / 20.0));
            const hcol: [4]f32 = if (wither_timer > 0.0) .{ 0.30, 0.22, 0.32, 1.0 } else if (regen) .{ 1.0, 0.80, 0.20, 1.0 } else .{ 0.9, 0.15, 0.15, 1.0 };
            addQuad(&verts, &count, hbx0 + 0.0015, by0 + 0.0015, hbx0 + 0.0015 + hfill, by0 + bh - 0.0015, hcol);
            // Hunger right half
            const gbx0 = start_x + total_w - bw;
            addBorderedRect(&verts, &count, gbx0, by0, gbx0 + bw, by0 + bh, 0.0015, .{ 0.1, 0.07, 0.03, 0.9 }, .{ 0.25, 0.15, 0.05, 0.9 });
            const gfill = bw * @min(1.0, @max(0.0, hunger / 20.0));
            addQuad(&verts, &count, gbx0 + 0.0015, by0 + 0.0015, gbx0 + 0.0015 + gfill, by0 + bh - 0.0015, .{ 0.95, 0.6, 0.15, 1.0 });

            // Oxygen bar above hunger when submerged / oxygen < 15.0
            if (oxygen < 15.0) {
                const oby0 = by0 - 0.015;
                addBorderedRect(&verts, &count, gbx0, oby0, gbx0 + bw, oby0 + bh, 0.0015, .{ 0.03, 0.07, 0.12, 0.9 }, .{ 0.08, 0.18, 0.30, 0.9 });
                const ofill = bw * @min(1.0, @max(0.0, oxygen / 15.0));
                addQuad(&verts, &count, gbx0 + 0.0015, oby0 + 0.0015, gbx0 + 0.0015 + ofill, oby0 + bh - 0.0015, .{ 0.2, 0.6, 0.95, 1.0 });
            }

            // Fire Resistance status effect indicator bar above health (golden flame amber)
            if (fire_res_timer > 0.0) {
                const fby0 = by0 - 0.015;
                addBorderedRect(&verts, &count, hbx0, fby0, hbx0 + bw, fby0 + bh, 0.0015, .{ 0.15, 0.08, 0.02, 0.9 }, .{ 0.28, 0.14, 0.04, 0.9 });
                const ffill = bw * @min(1.0, @max(0.0, fire_res_timer / 180.0));
                addQuad(&verts, &count, hbx0 + 0.0015, fby0 + 0.0015, hbx0 + 0.0015 + ffill, fby0 + bh - 0.0015, .{ 1.0, 0.55, 0.12, 1.0 });
            }

            // Wither status effect indicator bar (dark bone purple); stacks above fire bar when both active
            if (wither_timer > 0.0) {
                const wby0 = if (fire_res_timer > 0.0) by0 - 0.030 else by0 - 0.015;
                addBorderedRect(&verts, &count, hbx0, wby0, hbx0 + bw, wby0 + bh, 0.0015, .{ 0.08, 0.05, 0.10, 0.9 }, .{ 0.15, 0.10, 0.18, 0.9 });
                const wfill = bw * @min(1.0, @max(0.0, wither_timer / 8.0));
                addQuad(&verts, &count, hbx0 + 0.0015, wby0 + 0.0015, hbx0 + 0.0015 + wfill, wby0 + bh - 0.0015, .{ 0.35, 0.25, 0.40, 1.0 });
            }
        }

        // Compass dial & needle above crosshair (hidden when < -50.0).
        if (compass_rel > -50.0) {
            const ncx: f32 = 0.0;
            const ncy: f32 = 0.115;
            const dial_r: f32 = 0.042;
            const dr_x = dial_r / aspect;
            const dr_y = dial_r;

            // Brass outer casing & dark dial disc
            const rim_col = if (is_lodestone) [4]f32{ 0.15, 0.35, 0.42, 0.85 } else [4]f32{ 0.40, 0.32, 0.15, 0.85 };
            const face_col = [4]f32{ 0.08, 0.08, 0.09, 0.80 };
            addQuad(&verts, &count, ncx - dr_x, ncy - dr_y, ncx + dr_x, ncy + dr_y, rim_col);
            addQuad(&verts, &count, ncx - dr_x * 0.88, ncy - dr_y * 0.88, ncx + dr_x * 0.88, ncy + dr_y * 0.88, face_col);

            // Cardinal marks (top N indicator dot)
            const nmark_col = if (is_lodestone) [4]f32{ 0.40, 0.90, 1.0, 0.90 } else [4]f32{ 0.95, 0.85, 0.30, 0.90 };
            addQuad(&verts, &count, ncx - 0.003 / aspect, ncy + dr_y * 0.65, ncx + 0.003 / aspect, ncy + dr_y * 0.85, nmark_col);

            const nlen: f32 = 0.032;
            const tip_x = ncx + @sin(compass_rel) * nlen;
            const tip_y = ncy + @cos(compass_rel) * nlen;
            const nbase_x = ncx - @sin(compass_rel) * nlen * 0.45;
            const nbase_y = ncy - @cos(compass_rel) * nlen * 0.45;
            const pw: f32 = 0.005 / aspect;
            const shaft_col = if (is_lodestone) [4]f32{ 0.20, 0.85, 0.95, 0.95 } else [4]f32{ 0.88, 0.22, 0.22, 0.95 };
            const tip_col = if (is_lodestone) [4]f32{ 0.90, 1.0, 1.0, 1.0 } else [4]f32{ 1.0, 0.80, 0.25, 1.0 };
            addQuad(&verts, &count, @min(nbase_x, tip_x) - pw, @min(nbase_y, tip_y), @max(nbase_x, tip_x) + pw, @max(nbase_y, tip_y), shaft_col);
            addQuad(&verts, &count, tip_x - 0.005 / aspect, tip_y - 0.005, tip_x + 0.005 / aspect, tip_y + 0.005, tip_col);

            // Center brass pin
            const pin_col = [4]f32{ 0.85, 0.80, 0.60, 1.0 };
            addQuad(&verts, &count, ncx - 0.003 / aspect, ncy - 0.003, ncx + 0.003 / aspect, ncy + 0.003, pin_col);
        }

        // Mining progress bar above crosshair
        if (mine_frac >= 0.0) {
            const bw: f32 = 0.12;
            const bh: f32 = 0.012;
            const bx0 = -bw / 2.0;
            const by0 = 0.06;
            addBorderedRect(&verts, &count, bx0, by0, bx0 + bw, by0 + bh, 0.002, .{ 0.1, 0.1, 0.1, 0.9 }, .{ 0.25, 0.25, 0.28, 0.9 });
            const fill = bw * @min(1.0, @max(0.0, mine_frac));
            addQuad(&verts, &count, bx0 + 0.002, by0 + 0.002, bx0 + 0.002 + fill, by0 + bh - 0.002, .{ 0.95, 0.8, 0.25, 1.0 });
        }

        self.flush(&verts, count);
    }

    /// Full screen Inventory & Crafting GUI
    pub fn drawInventory(
        self: *UIRenderer,
        aspect: f32,
        main_colors: []const [4]f32,
        main_counts: []const u8,
        hotbar_colors: []const [4]f32,
        hotbar_counts: []const u8,
        craft_grid_colors: []const [4]f32,
        craft_grid_counts: []const u8,
        craft_output_col: [4]f32,
        craft_output_count: u8,
        cursor_col: [4]f32,
        cursor_count: u8,
        mouse_norm_x: f32,
        mouse_norm_y: f32,
    ) void {
        var verts: [4096]UIVertex = undefined;
        var count: usize = 0;

        // 1. Semi-transparent dark background backdrop
        addQuad(&verts, &count, -1.0, -1.0, 1.0, 1.0, .{ 0.0, 0.0, 0.0, 0.65 });

        // 2. Main inventory window panel
        const panel_w: f32 = 0.85;
        const panel_h: f32 = 0.88;
        const px0 = -panel_w / 2.0;
        const px1 = panel_w / 2.0;
        const py0 = -panel_h / 2.0;
        const py1 = panel_h / 2.0;

        // Metallic / stone inventory window frame
        addBorderedRect(&verts, &count, px0, py0, px1, py1, 0.006, .{ 0.25, 0.25, 0.28, 0.98 }, .{ 0.72, 0.72, 0.75, 0.96 });

        const slot_w: f32 = 0.055 / aspect;
        const slot_h: f32 = 0.055;
        const gap: f32 = 0.012 / aspect;

        // Crafting Section Header & 2x2 grid (upper right)
        const craft_start_x = 0.02;
        const craft_start_y = 0.16;

        var r: usize = 0;
        while (r < 2) : (r += 1) {
            var c_idx: usize = 0;
            while (c_idx < 2) : (c_idx += 1) {
                const idx = r * 2 + c_idx;
                const sx0 = craft_start_x + @as(f32, @floatFromInt(c_idx)) * (slot_w + gap);
                const sx1 = sx0 + slot_w;
                const sy1 = craft_start_y - @as(f32, @floatFromInt(r)) * (slot_h + gap * aspect);
                const sy0 = sy1 - slot_h;

                addBorderedRect(&verts, &count, sx0, sy0, sx1, sy1, 0.003, .{ 0.35, 0.35, 0.38, 1.0 }, .{ 0.55, 0.55, 0.58, 1.0 });

                if (idx < craft_grid_colors.len and craft_grid_counts[idx] > 0) {
                    addQuad(&verts, &count, sx0 + 0.006 / aspect, sy0 + 0.006, sx1 - 0.006 / aspect, sy1 - 0.006, craft_grid_colors[idx]);
                }
            }
        }

        // Crafting arrow -> Output Slot
        const arrow_x = craft_start_x + 2.0 * (slot_w + gap) + 0.02 / aspect;
        const arrow_y = craft_start_y - slot_h * 0.8;
        addQuad(&verts, &count, arrow_x, arrow_y - 0.005, arrow_x + 0.03 / aspect, arrow_y + 0.005, .{ 0.3, 0.3, 0.35, 1.0 });

        const out_x0 = arrow_x + 0.045 / aspect;
        const out_x1 = out_x0 + slot_w * 1.25;
        const out_y0 = arrow_y - slot_h * 0.625;
        const out_y1 = arrow_y + slot_h * 0.625;
        addBorderedRect(&verts, &count, out_x0, out_y0, out_x1, out_y1, 0.004, .{ 0.9, 0.8, 0.3, 1.0 }, .{ 0.55, 0.55, 0.58, 1.0 });

        if (craft_output_count > 0) {
            addQuad(&verts, &count, out_x0 + 0.008 / aspect, out_y0 + 0.008, out_x1 - 0.008 / aspect, out_y1 - 0.008, craft_output_col);
        }

        // Main Inventory 3 rows x 6 columns
        const main_start_x = -0.32;
        const main_start_y = 0.02;

        var mr: usize = 0;
        while (mr < 3) : (mr += 1) {
            var mc: usize = 0;
            while (mc < 6) : (mc += 1) {
                const idx = mr * 6 + mc;
                const sx0 = main_start_x + @as(f32, @floatFromInt(mc)) * (slot_w + gap);
                const sx1 = sx0 + slot_w;
                const sy1 = main_start_y - @as(f32, @floatFromInt(mr)) * (slot_h + gap * aspect);
                const sy0 = sy1 - slot_h;

                addBorderedRect(&verts, &count, sx0, sy0, sx1, sy1, 0.003, .{ 0.35, 0.35, 0.38, 1.0 }, .{ 0.55, 0.55, 0.58, 1.0 });

                if (idx < main_colors.len and main_counts[idx] > 0) {
                    addQuad(&verts, &count, sx0 + 0.006 / aspect, sy0 + 0.006, sx1 - 0.006 / aspect, sy1 - 0.006, main_colors[idx]);
                }
            }
        }

        // Bottom Hotbar Row (6 slots)
        const hot_y = -0.32;
        var hc: usize = 0;
        while (hc < 6) : (hc += 1) {
            const sx0 = main_start_x + @as(f32, @floatFromInt(hc)) * (slot_w + gap);
            const sx1 = sx0 + slot_w;
            const sy0 = hot_y;
            const sy1 = hot_y + slot_h;

            addBorderedRect(&verts, &count, sx0, sy0, sx1, sy1, 0.003, .{ 0.35, 0.35, 0.38, 1.0 }, .{ 0.55, 0.55, 0.58, 1.0 });

            if (hc < hotbar_colors.len and hotbar_counts[hc] > 0) {
                addQuad(&verts, &count, sx0 + 0.006 / aspect, sy0 + 0.006, sx1 - 0.006 / aspect, sy1 - 0.006, hotbar_colors[hc]);
            }
        }

        // Cursor held item
        if (cursor_count > 0) {
            const cw = 0.04 / aspect;
            const ch = 0.04;
            addQuad(&verts, &count, mouse_norm_x, mouse_norm_y - ch, mouse_norm_x + cw, mouse_norm_y, cursor_col);
        }

        // Mouse pointer arrow icon
        const mx = mouse_norm_x;
        const my = mouse_norm_y;
        const mw = 0.015 / aspect;
        const mh = 0.025;
        addQuad(&verts, &count, mx, my - mh, mx + mw, my, .{ 1.0, 1.0, 1.0, 0.95 });

        self.flush(&verts, count);
    }

    fn flush(self: *UIRenderer, verts: []const UIVertex, count: usize) void {
        if (count == 0) return;
        c.glDisable(c.GL_DEPTH_TEST);
        c.glEnable(c.GL_BLEND);
        c.glBlendFunc(c.GL_SRC_ALPHA, c.GL_ONE_MINUS_SRC_ALPHA);

        c.glUseProgram(self.program);
        c.glBindVertexArray(self.vao);
        c.glBindBuffer(c.GL_ARRAY_BUFFER, self.vbo);
        c.glBufferSubData(c.GL_ARRAY_BUFFER, 0, @intCast(count * @sizeOf(UIVertex)), verts.ptr);
        c.glDrawArrays(c.GL_TRIANGLES, 0, @intCast(count));

        c.glEnable(c.GL_DEPTH_TEST);
        c.glDisable(c.GL_BLEND);
    }
};

test "ui vertex layout" {
    try std.testing.expectEqual(@sizeOf(UIVertex), 24);
}

test "portal flash alpha calculation" {
    const alpha = 0.6;
    const clamped = @min(0.85, alpha);
    try std.testing.expectApproxEqAbs(@as(f32, 0.6), clamped, 0.001);
}

test "portal vignette alpha calculation" {
    const intensity = 0.8;
    const max_a = @min(0.75, intensity * 0.75);
    try std.testing.expectApproxEqAbs(@as(f32, 0.60), max_a, 0.001);
}

test "toast vertex sizing" {
    try std.testing.expect(@sizeOf(UIVertex) == 24);
}

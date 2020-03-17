##
## * Copyright (c) 2020 rxi
## *
## * This library is free software; you can redistribute it and/or modify it
## * under the terms of the MIT license. See `microui.c` for details.
##

const
  MU_VERSION* = "2.00"

const
  MU_COMMANDLIST_SIZE* = (256 * 1024)
  MU_ROOTLIST_SIZE* = 32
  MU_CONTAINERSTACK_SIZE* = 32
  MU_CLIPSTACK_SIZE* = 32
  MU_IDSTACK_SIZE* = 32
  MU_LAYOUTSTACK_SIZE* = 16
  MU_CONTAINERPOOL_SIZE* = 48
  MU_TREENODEPOOL_SIZE* = 48
  MU_MAX_WIDTHS* = 16

type
  MU_REAL* = cfloat

const
  MU_REAL_FMT* = "%.3g"
  MU_SLIDER_FMT* = "%.2f"
  MU_MAX_FMT* = 127

template mu_min*(a, b: untyped): untyped =
  (if (a) < (b): (a) else: (b))

template mu_max*(a, b: untyped): untyped =
  (if (a) > (b): (a) else: (b))

template mu_clamp*(x, a, b: untyped): untyped =
  mu_min(b, mu_max(a, x))

const
  MU_CLIP_PART* = 1
  MU_CLIP_ALL* = 2

const
  MU_COMMAND_JUMP* = 1
  MU_COMMAND_CLIP* = 2
  MU_COMMAND_RECT* = 3
  MU_COMMAND_TEXT* = 4
  MU_COMMAND_ICON* = 5
  MU_COMMAND_MAX* = 6

const
  MU_COLOR_TEXT* = 0
  MU_COLOR_BORDER* = 1
  MU_COLOR_WINDOWBG* = 2
  MU_COLOR_TITLEBG* = 3
  MU_COLOR_TITLETEXT* = 4
  MU_COLOR_PANELBG* = 5
  MU_COLOR_BUTTON* = 6
  MU_COLOR_BUTTONHOVER* = 7
  MU_COLOR_BUTTONFOCUS* = 8
  MU_COLOR_BASE* = 9
  MU_COLOR_BASEHOVER* = 10
  MU_COLOR_BASEFOCUS* = 11
  MU_COLOR_SCROLLBASE* = 12
  MU_COLOR_SCROLLTHUMB* = 13
  MU_COLOR_MAX* = 14

const
  MU_ICON_CLOSE* = 1
  MU_ICON_CHECK* = 2
  MU_ICON_COLLAPSED* = 3
  MU_ICON_EXPANDED* = 4
  MU_ICON_MAX* = 5

const
  MU_RES_ACTIVE* = (1 shl 0)
  MU_RES_SUBMIT* = (1 shl 1)
  MU_RES_CHANGE* = (1 shl 2)

const
  MU_OPT_ALIGNCENTER* = (1 shl 0)
  MU_OPT_ALIGNRIGHT* = (1 shl 1)
  MU_OPT_NOINTERACT* = (1 shl 2)
  MU_OPT_NOFRAME* = (1 shl 3)
  MU_OPT_NORESIZE* = (1 shl 4)
  MU_OPT_NOSCROLL* = (1 shl 5)
  MU_OPT_NOCLOSE* = (1 shl 6)
  MU_OPT_NOTITLE* = (1 shl 7)
  MU_OPT_HOLDFOCUS* = (1 shl 8)
  MU_OPT_AUTOSIZE* = (1 shl 9)
  MU_OPT_POPUP* = (1 shl 10)
  MU_OPT_CLOSED* = (1 shl 11)
  MU_OPT_EXPANDED* = (1 shl 12)

const
  MU_MOUSE_LEFT* = (1 shl 0)
  MU_MOUSE_RIGHT* = (1 shl 1)
  MU_MOUSE_MIDDLE* = (1 shl 2)

const
  MU_KEY_SHIFT* = (1 shl 0)
  MU_KEY_CTRL* = (1 shl 1)
  MU_KEY_ALT* = (1 shl 2)
  MU_KEY_BACKSPACE* = (1 shl 3)
  MU_KEY_RETURN* = (1 shl 4)

type
  mu_Id* = cuint
  mu_Real* = MU_REAL
  mu_Font* = pointer
  mu_Vec2* {.importc: "mu_Vec2", header: "microui.h", bycopy.} = object
    x* {.importc: "x".}: cint
    y* {.importc: "y".}: cint

  mu_Rect* {.importc: "mu_Rect", header: "microui.h", bycopy.} = object
    x* {.importc: "x".}: cint
    y* {.importc: "y".}: cint
    w* {.importc: "w".}: cint
    h* {.importc: "h".}: cint

  mu_Color* {.importc: "mu_Color", header: "microui.h", bycopy.} = object
    r* {.importc: "r".}: byte
    g* {.importc: "g".}: byte
    b* {.importc: "b".}: byte
    a* {.importc: "a".}: byte

  mu_PoolItem* {.importc: "mu_PoolItem", header: "microui.h", bycopy.} = object
    id* {.importc: "id".}: mu_Id
    last_update* {.importc: "last_update".}: cint

  mu_BaseCommand* {.importc: "mu_BaseCommand", header: "microui.h", bycopy.} = object
    `type`* {.importc: "type".}: cint
    size* {.importc: "size".}: cint

  mu_JumpCommand* {.importc: "mu_JumpCommand", header: "microui.h", bycopy.} = object
    base* {.importc: "base".}: mu_BaseCommand
    dst* {.importc: "dst".}: pointer

  mu_ClipCommand* {.importc: "mu_ClipCommand", header: "microui.h", bycopy.} = object
    base* {.importc: "base".}: mu_BaseCommand
    rect* {.importc: "rect".}: mu_Rect

  mu_RectCommand* {.importc: "mu_RectCommand", header: "microui.h", bycopy.} = object
    base* {.importc: "base".}: mu_BaseCommand
    rect* {.importc: "rect".}: mu_Rect
    color* {.importc: "color".}: mu_Color

  mu_TextCommand* {.importc: "mu_TextCommand", header: "microui.h", bycopy.} = object
    base* {.importc: "base".}: mu_BaseCommand
    font* {.importc: "font".}: mu_Font
    pos* {.importc: "pos".}: mu_Vec2
    color* {.importc: "color".}: mu_Color
    str* {.importc: "str".}: array[1, char]

  mu_IconCommand* {.importc: "mu_IconCommand", header: "microui.h", bycopy.} = object
    base* {.importc: "base".}: mu_BaseCommand
    rect* {.importc: "rect".}: mu_Rect
    id* {.importc: "id".}: cint
    color* {.importc: "color".}: mu_Color

  mu_Command* {.importc: "mu_Command", header: "microui.h", bycopy.} = object {.union.}
    `type`* {.importc: "type".}: cint
    base* {.importc: "base".}: mu_BaseCommand
    jump* {.importc: "jump".}: mu_JumpCommand
    clip* {.importc: "clip".}: mu_ClipCommand
    rect* {.importc: "rect".}: mu_RectCommand
    text* {.importc: "text".}: mu_TextCommand
    icon* {.importc: "icon".}: mu_IconCommand

  mu_Layout* {.importc: "mu_Layout", header: "microui.h", bycopy.} = object
    body* {.importc: "body".}: mu_Rect
    next* {.importc: "next".}: mu_Rect
    position* {.importc: "position".}: mu_Vec2
    size* {.importc: "size".}: mu_Vec2
    max* {.importc: "max".}: mu_Vec2
    widths* {.importc: "widths".}: array[MU_MAX_WIDTHS, cint]
    items* {.importc: "items".}: cint
    item_index* {.importc: "item_index".}: cint
    next_row* {.importc: "next_row".}: cint
    next_type* {.importc: "next_type".}: cint
    indent* {.importc: "indent".}: cint

  mu_Container* {.importc: "mu_Container", header: "microui.h", bycopy.} = object
    head* {.importc: "head".}: ptr mu_Command
    tail* {.importc: "tail".}: ptr mu_Command
    rect* {.importc: "rect".}: mu_Rect
    body* {.importc: "body".}: mu_Rect
    content_size* {.importc: "content_size".}: mu_Vec2
    scroll* {.importc: "scroll".}: mu_Vec2
    zindex* {.importc: "zindex".}: cint
    open* {.importc: "open".}: cint

  mu_Style* {.importc: "mu_Style", header: "microui.h", bycopy.} = object
    font* {.importc: "font".}: mu_Font
    size* {.importc: "size".}: mu_Vec2
    padding* {.importc: "padding".}: cint
    spacing* {.importc: "spacing".}: cint
    indent* {.importc: "indent".}: cint
    title_height* {.importc: "title_height".}: cint
    scrollbar_size* {.importc: "scrollbar_size".}: cint
    thumb_size* {.importc: "thumb_size".}: cint
    colors* {.importc: "colors".}: array[MU_COLOR_MAX, mu_Color]

  INNER_C_STRUCT_microui_216* {.importc: "no_name", header: "microui.h", bycopy.} = object
    idx* {.importc: "idx".}: cint
    items* {.importc: "items".}: array[MU_COMMANDLIST_SIZE, char]

  INNER_C_STRUCT_microui_217* {.importc: "no_name", header: "microui.h", bycopy.} = object
    idx* {.importc: "idx".}: cint
    items* {.importc: "items".}: array[MU_ROOTLIST_SIZE, ptr mu_Container]

  INNER_C_STRUCT_microui_218* {.importc: "no_name", header: "microui.h", bycopy.} = object
    idx* {.importc: "idx".}: cint
    items* {.importc: "items".}: array[MU_CONTAINERSTACK_SIZE, ptr mu_Container]

  INNER_C_STRUCT_microui_219* {.importc: "no_name", header: "microui.h", bycopy.} = object
    idx* {.importc: "idx".}: cint
    items* {.importc: "items".}: array[MU_CLIPSTACK_SIZE, mu_Rect]

  INNER_C_STRUCT_microui_220* {.importc: "no_name", header: "microui.h", bycopy.} = object
    idx* {.importc: "idx".}: cint
    items* {.importc: "items".}: array[MU_IDSTACK_SIZE, mu_Id]

  INNER_C_STRUCT_microui_221* {.importc: "no_name", header: "microui.h", bycopy.} = object
    idx* {.importc: "idx".}: cint
    items* {.importc: "items".}: array[MU_LAYOUTSTACK_SIZE, mu_Layout]

  mu_Context* {.importc: "mu_Context", header: "microui.h", bycopy.} = object
    text_width* {.importc: "text_width".}: proc (font: mu_Font; str: cstring; len: cint): cint {.
        cdecl.}               ##  callbacks
    text_height* {.importc: "text_height".}: proc (font: mu_Font): cint {.cdecl.}
    draw_frame* {.importc: "draw_frame".}: proc (ctx: ptr mu_Context; rect: mu_Rect;
        colorid: cint) {.cdecl.} ##  core state
    privstyle* {.importc: "privstyle".}: mu_Style
    style* {.importc: "style".}: ptr mu_Style
    hover* {.importc: "hover".}: mu_Id
    focus* {.importc: "focus".}: mu_Id
    last_id* {.importc: "last_id".}: mu_Id
    last_rect* {.importc: "last_rect".}: mu_Rect
    last_zindex* {.importc: "last_zindex".}: cint
    updated_focus* {.importc: "updated_focus".}: cint
    frame* {.importc: "frame".}: cint
    hover_root* {.importc: "hover_root".}: ptr mu_Container
    next_hover_root* {.importc: "next_hover_root".}: ptr mu_Container
    scroll_target* {.importc: "scroll_target".}: ptr mu_Container
    number_edit_buf* {.importc: "number_edit_buf".}: array[MU_MAX_FMT, char]
    number_edit* {.importc: "number_edit".}: mu_Id ##  stacks
    command_list* {.importc: "command_list".}: INNER_C_STRUCT_microui_216
    root_list* {.importc: "root_list".}: INNER_C_STRUCT_microui_217
    container_stack* {.importc: "container_stack".}: INNER_C_STRUCT_microui_218
    clip_stack* {.importc: "clip_stack".}: INNER_C_STRUCT_microui_219
    id_stack* {.importc: "id_stack".}: INNER_C_STRUCT_microui_220
    layout_stack* {.importc: "layout_stack".}: INNER_C_STRUCT_microui_221 ##  retained state pools
    container_pool* {.importc: "container_pool".}: array[MU_CONTAINERPOOL_SIZE,
        mu_PoolItem]
    containers* {.importc: "containers".}: array[MU_CONTAINERPOOL_SIZE, mu_Container]
    treenode_pool* {.importc: "treenode_pool".}: array[MU_TREENODEPOOL_SIZE,
        mu_PoolItem]          ##  input state
    mouse_pos* {.importc: "mouse_pos".}: mu_Vec2
    last_mouse_pos* {.importc: "last_mouse_pos".}: mu_Vec2
    mouse_delta* {.importc: "mouse_delta".}: mu_Vec2
    scroll_delta* {.importc: "scroll_delta".}: mu_Vec2
    mouse_down* {.importc: "mouse_down".}: cint
    mouse_pressed* {.importc: "mouse_pressed".}: cint
    key_down* {.importc: "key_down".}: cint
    key_pressed* {.importc: "key_pressed".}: cint
    input_text* {.importc: "input_text".}: array[32, char]


proc mu_init*(ctx: ptr mu_Context) {.cdecl, importc: "mu_init", header: "microui.h".}
proc mu_begin*(ctx: ptr mu_Context) {.cdecl, importc: "mu_begin", header: "microui.h".}
proc mu_end*(ctx: ptr mu_Context) {.cdecl, importc: "mu_end", header: "microui.h".}
proc mu_set_focus*(ctx: ptr mu_Context; id: mu_Id) {.cdecl, importc: "mu_set_focus",
    header: "microui.h".}
proc mu_get_id*(ctx: ptr mu_Context; data: pointer; size: cint): mu_Id {.cdecl,
    importc: "mu_get_id", header: "microui.h".}
proc mu_push_id*(ctx: ptr mu_Context; data: pointer; size: cint) {.cdecl,
    importc: "mu_push_id", header: "microui.h".}
proc mu_pop_id*(ctx: ptr mu_Context) {.cdecl, importc: "mu_pop_id", header: "microui.h".}
proc mu_push_clip_rect*(ctx: ptr mu_Context; rect: mu_Rect) {.cdecl,
    importc: "mu_push_clip_rect", header: "microui.h".}
proc mu_pop_clip_rect*(ctx: ptr mu_Context) {.cdecl, importc: "mu_pop_clip_rect",
    header: "microui.h".}
proc mu_get_clip_rect*(ctx: ptr mu_Context): mu_Rect {.cdecl,
    importc: "mu_get_clip_rect", header: "microui.h".}
proc mu_check_clip*(ctx: ptr mu_Context; r: mu_Rect): cint {.cdecl,
    importc: "mu_check_clip", header: "microui.h".}
proc mu_get_current_container*(ctx: ptr mu_Context): ptr mu_Container {.cdecl,
    importc: "mu_get_current_container", header: "microui.h".}
proc mu_get_container*(ctx: ptr mu_Context; name: cstring): ptr mu_Container {.cdecl,
    importc: "mu_get_container", header: "microui.h".}
proc mu_bring_to_front*(ctx: ptr mu_Context; cnt: ptr mu_Container) {.cdecl,
    importc: "mu_bring_to_front", header: "microui.h".}
proc mu_pool_init*(ctx: ptr mu_Context; items: ptr mu_PoolItem; len: cint; id: mu_Id): cint {.
    cdecl, importc: "mu_pool_init", header: "microui.h".}
proc mu_pool_get*(ctx: ptr mu_Context; items: ptr mu_PoolItem; len: cint; id: mu_Id): cint {.
    cdecl, importc: "mu_pool_get", header: "microui.h".}
proc mu_pool_update*(ctx: ptr mu_Context; items: ptr mu_PoolItem; idx: cint) {.cdecl,
    importc: "mu_pool_update", header: "microui.h".}
proc mu_input_mousemove*(ctx: ptr mu_Context; x: cint; y: cint) {.cdecl,
    importc: "mu_input_mousemove", header: "microui.h".}
proc mu_input_mousedown*(ctx: ptr mu_Context; x: cint; y: cint; btn: cint) {.cdecl,
    importc: "mu_input_mousedown", header: "microui.h".}
proc mu_input_mouseup*(ctx: ptr mu_Context; x: cint; y: cint; btn: cint) {.cdecl,
    importc: "mu_input_mouseup", header: "microui.h".}
proc mu_input_scroll*(ctx: ptr mu_Context; x: cint; y: cint) {.cdecl,
    importc: "mu_input_scroll", header: "microui.h".}
proc mu_input_keydown*(ctx: ptr mu_Context; key: cint) {.cdecl,
    importc: "mu_input_keydown", header: "microui.h".}
proc mu_input_keyup*(ctx: ptr mu_Context; key: cint) {.cdecl,
    importc: "mu_input_keyup", header: "microui.h".}
proc mu_input_text*(ctx: ptr mu_Context; text: cstring) {.cdecl,
    importc: "mu_input_text", header: "microui.h".}
proc mu_push_command*(ctx: ptr mu_Context; `type`: cint; size: cint): ptr mu_Command {.
    cdecl, importc: "mu_push_command", header: "microui.h".}
proc mu_next_command*(ctx: ptr mu_Context; cmd: ptr ptr mu_Command): cint {.cdecl,
    importc: "mu_next_command", header: "microui.h".}
proc mu_set_clip*(ctx: ptr mu_Context; rect: mu_Rect) {.cdecl, importc: "mu_set_clip",
    header: "microui.h".}
proc mu_draw_rect*(ctx: ptr mu_Context; rect: mu_Rect; color: mu_Color) {.cdecl,
    importc: "mu_draw_rect", header: "microui.h".}
proc mu_draw_box*(ctx: ptr mu_Context; rect: mu_Rect; color: mu_Color) {.cdecl,
    importc: "mu_draw_box", header: "microui.h".}
proc mu_draw_text*(ctx: ptr mu_Context; font: mu_Font; str: cstring; len: cint;
                  pos: mu_Vec2; color: mu_Color) {.cdecl, importc: "mu_draw_text",
    header: "microui.h".}
proc mu_draw_icon*(ctx: ptr mu_Context; id: cint; rect: mu_Rect; color: mu_Color) {.cdecl,
    importc: "mu_draw_icon", header: "microui.h".}
proc mu_layout_row*(ctx: ptr mu_Context; items: cint; widths: ptr cint; height: cint) {.
    cdecl, importc: "mu_layout_row", header: "microui.h".}
proc mu_layout_width*(ctx: ptr mu_Context; width: cint) {.cdecl,
    importc: "mu_layout_width", header: "microui.h".}
proc mu_layout_height*(ctx: ptr mu_Context; height: cint) {.cdecl,
    importc: "mu_layout_height", header: "microui.h".}
proc mu_layout_begin_column*(ctx: ptr mu_Context) {.cdecl,
    importc: "mu_layout_begin_column", header: "microui.h".}
proc mu_layout_end_column*(ctx: ptr mu_Context) {.cdecl,
    importc: "mu_layout_end_column", header: "microui.h".}
proc mu_layout_set_next*(ctx: ptr mu_Context; r: mu_Rect; relative: cint) {.cdecl,
    importc: "mu_layout_set_next", header: "microui.h".}
proc mu_layout_next*(ctx: ptr mu_Context): mu_Rect {.cdecl, importc: "mu_layout_next",
    header: "microui.h".}
proc mu_draw_control_frame*(ctx: ptr mu_Context; id: mu_Id; rect: mu_Rect;
                           colorid: cint; opt: cint) {.cdecl,
    importc: "mu_draw_control_frame", header: "microui.h".}
proc mu_draw_control_text*(ctx: ptr mu_Context; str: cstring; rect: mu_Rect;
                          colorid: cint; opt: cint) {.cdecl,
    importc: "mu_draw_control_text", header: "microui.h".}
proc mu_mouse_over*(ctx: ptr mu_Context; rect: mu_Rect): cint {.cdecl,
    importc: "mu_mouse_over", header: "microui.h".}
proc mu_update_control*(ctx: ptr mu_Context; id: mu_Id; rect: mu_Rect; opt: cint) {.cdecl,
    importc: "mu_update_control", header: "microui.h".}
template mu_button*(ctx, label: untyped): untyped =
  mu_button_ex(ctx, label, 0, MU_OPT_ALIGNCENTER)

template mu_textbox*(ctx, buf, bufsz: untyped): untyped =
  mu_textbox_ex(ctx, buf, bufsz, 0)

template mu_slider*(ctx, value, lo, hi: untyped): untyped =
  mu_slider_ex(ctx, value, lo, hi, 0, MU_SLIDER_FMT, MU_OPT_ALIGNCENTER)

template mu_number*(ctx, value, step: untyped): untyped =
  mu_number_ex(ctx, value, step, MU_SLIDER_FMT, MU_OPT_ALIGNCENTER)

template mu_header*(ctx, label: untyped): untyped =
  mu_header_ex(ctx, label, 0)

template mu_begin_treenode*(ctx, label: untyped): untyped =
  mu_begin_treenode_ex(ctx, label, 0)

template mu_begin_window*(ctx, title, rect: untyped): untyped =
  mu_begin_window_ex(ctx, title, rect, 0)

template mu_begin_panel*(ctx, name: untyped): untyped =
  mu_begin_panel_ex(ctx, name, 0)

proc mu_text*(ctx: ptr mu_Context; text: cstring) {.cdecl, importc: "mu_text",
    header: "microui.h".}
proc mu_label*(ctx: ptr mu_Context; text: cstring) {.cdecl, importc: "mu_label",
    header: "microui.h".}
proc mu_button_ex*(ctx: ptr mu_Context; label: cstring; icon: cint; opt: cint): cint {.
    cdecl, importc: "mu_button_ex", header: "microui.h".}
proc mu_checkbox*(ctx: ptr mu_Context; label: cstring; state: ptr cint): cint {.cdecl,
    importc: "mu_checkbox", header: "microui.h".}
proc mu_textbox_raw*(ctx: ptr mu_Context; buf: cstring; bufsz: cint; id: mu_Id;
                    r: mu_Rect; opt: cint): cint {.cdecl, importc: "mu_textbox_raw",
    header: "microui.h".}
proc mu_textbox_ex*(ctx: ptr mu_Context; buf: cstring; bufsz: cint; opt: cint): cint {.
    cdecl, importc: "mu_textbox_ex", header: "microui.h".}
proc mu_slider_ex*(ctx: ptr mu_Context; value: ptr mu_Real; low: mu_Real; high: mu_Real;
                  step: mu_Real; fmt: cstring; opt: cint): cint {.cdecl,
    importc: "mu_slider_ex", header: "microui.h".}
proc mu_number_ex*(ctx: ptr mu_Context; value: ptr mu_Real; step: mu_Real; fmt: cstring;
                  opt: cint): cint {.cdecl, importc: "mu_number_ex",
                                  header: "microui.h".}
proc mu_header_ex*(ctx: ptr mu_Context; label: cstring; opt: cint): cint {.cdecl,
    importc: "mu_header_ex", header: "microui.h".}
proc mu_begin_treenode_ex*(ctx: ptr mu_Context; label: cstring; opt: cint): cint {.cdecl,
    importc: "mu_begin_treenode_ex", header: "microui.h".}
proc mu_end_treenode*(ctx: ptr mu_Context) {.cdecl, importc: "mu_end_treenode",
    header: "microui.h".}
proc mu_begin_window_ex*(ctx: ptr mu_Context; title: cstring; rect: mu_Rect; opt: cint): cint {.
    cdecl, importc: "mu_begin_window_ex", header: "microui.h".}
proc mu_end_window*(ctx: ptr mu_Context) {.cdecl, importc: "mu_end_window",
                                       header: "microui.h".}
proc mu_open_popup*(ctx: ptr mu_Context; name: cstring) {.cdecl,
    importc: "mu_open_popup", header: "microui.h".}
proc mu_begin_popup*(ctx: ptr mu_Context; name: cstring): cint {.cdecl,
    importc: "mu_begin_popup", header: "microui.h".}
proc mu_end_popup*(ctx: ptr mu_Context) {.cdecl, importc: "mu_end_popup",
                                      header: "microui.h".}
proc mu_begin_panel_ex*(ctx: ptr mu_Context; name: cstring; opt: cint) {.cdecl,
    importc: "mu_begin_panel_ex", header: "microui.h".}
proc mu_end_panel*(ctx: ptr mu_Context) {.cdecl, importc: "mu_end_panel",
                                      header: "microui.h".}
/// 图标名常量（对应 resources/base/media 下的 SVG 文件名，如 play.svg）
/// 调用处用 SFIcons.sf_play 等，SFIcon 组件用 Image($r('app.media.<name>')) 渲染
export class SFIcons {
  static readonly sf_play: string = 'play';
  static readonly sf_pause: string = 'pause';
  static readonly sf_pause_fill: string = 'pause';
  static readonly sf_previous: string = 'previous';
  static readonly sf_next: string = 'next';
  static readonly sf_queue: string = 'queue';
  static readonly sf_repeat: string = 'repeat';
  static readonly sf_shuffle: string = 'shuffle';
  static readonly sf_repeat_1: string = 'repeat_1';
  static readonly sf_heart: string = 'heart';
  static readonly sf_heart_fill: string = 'heart_fill';
  static readonly sf_more: string = 'more';
  static readonly sf_play_fill: string = 'play';
  static readonly sf_backward_fill: string = 'previous';
  static readonly sf_forward_fill: string = 'next';
  static readonly sf_list_bullet: string = 'queue';
  static readonly sf_ellipsis: string = 'more';
  static readonly sf_crown: string = 'crown';
  // tab：normal / fill 两套（对应原项目：媒体库 sficon，艺术家/专辑/设置 fluentui）
  static readonly sf_music_note_square_stack: string = 'tab_music';
  static readonly sf_music_note_square_stack_fill: string = 'tab_music_fill';
  static readonly sf_person_fill: string = 'tab_person';
  static readonly sf_person_fill_active: string = 'tab_person_fill';
  static readonly sf_opticaldisc: string = 'tab_cd';
  static readonly sf_opticaldisc_fill: string = 'tab_cd_fill';
  static readonly sf_gearshape: string = 'tab_settings';
  static readonly sf_gearshape_fill: string = 'tab_settings_fill';
  static readonly sf_play_circle: string = 'play';
  // 输出设备（sf_dot_radiowaves_left_and_right，选当前输出设备）
  static readonly sf_output: string = 'output';
  // 输出设备（airplay_audio，airplay 风格三角+同心圆弧）
  static readonly sf_airplay_audio: string = 'airplay_audio';
  // 设置页图标
  static readonly sf_setting_media: string = 'setting_media';
  static readonly sf_setting_interface: string = 'setting_interface';
  static readonly sf_setting_audio: string = 'setting_audio';
  static readonly sf_setting_lyrics: string = 'setting_lyrics';
  // 歌词引号图标（fluentui text_quote 两变体：lyric_quote 线条 / lyric_quote_fill 实心）
  static readonly sf_lyric_quote: string = 'lyric_quote';
  static readonly sf_lyric_quote_fill: string = 'lyric_quote_fill';
  // quote.bubble（SF Symbol 0x10032E/0x10032F）——Flutter 版歌词按钮同款气泡引号
  static readonly sf_lyric_quote_bubble: string = 'lyric_quote_bubble';
  static readonly sf_lyric_quote_bubble_fill: string = 'lyric_quote_bubble_fill';
  static readonly sf_setting_playback: string = 'setting_playback';
  static readonly sf_setting_ranking: string = 'setting_ranking';
  static readonly sf_setting_more: string = 'setting_more';
  static readonly sf_setting_about: string = 'setting_about';
}

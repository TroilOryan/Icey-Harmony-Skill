/// 格式化工具（时间/百分比等纯静态函数）
/// 沿用鸿蒙习惯放 services/，对齐 CoverColorExtractor 等纯工具服务

export class FormatUtils {
  /// 受支持的音频扩展名白名单（导入过滤/扫描过滤/解析校验共用）
  static readonly AUDIO_EXTS: string[] = ['mp3', 'flac', 'wav', 'aac', 'm4a', 'ogg', 'opus', 'ape', 'wv'];

  /// 判断 URI 是否为受支持的音频文件（扩展名白名单 AUDIO_EXTS）
  /// 兜底根因：文件选择器 mergeMode=AUDIO 可能不生效（用户可选中任意文件），且
  /// AVMetadataExtractor 对非媒体文件（如 .lrc 歌词）可能返回空 metadata 而不报错——
  /// 导入管线/解析器都必须按扩展名过滤，否则 lrc/图片/文档会以"时长 0 的假歌曲"混入媒体库
  static isAudioFile(uri: string): boolean {
    try {
      let path = uri;
      const qIdx = path.indexOf('?');
      if (qIdx >= 0) path = path.substring(0, qIdx);
      const dotIdx = path.lastIndexOf('.');
      if (dotIdx < 0 || dotIdx === path.length - 1) return false;
      const ext = path.substring(dotIdx + 1).toLowerCase();
      return FormatUtils.AUDIO_EXTS.indexOf(ext) >= 0;
    } catch (_) {
      return false;
    }
  }

  /// 扩展名 → MIME（隐式 Want 打开文件用，与目标应用注册的 type 对齐）
  /// 用于「在音乐标签中打开」：把音频 uri + 对应 MIME 传给系统，由系统匹配已注册
  /// FileOpen 能力的目标应用拉起编辑
  static mimeOf(uri: string): string {
    try {
      let path = uri;
      const qIdx = path.indexOf('?');
      if (qIdx >= 0) path = path.substring(0, qIdx);
      const dotIdx = path.lastIndexOf('.');
      if (dotIdx < 0 || dotIdx === path.length - 1) return 'application/octet-stream';
      const ext = path.substring(dotIdx + 1).toLowerCase();
      switch (ext) {
        case 'mp3': return 'audio/mpeg';
        case 'flac': return 'audio/flac';
        case 'wav': case 'wave': return 'audio/wav';
        case 'aac': return 'audio/aac';
        case 'm4a': return 'audio/mp4';
        case 'ogg': return 'audio/ogg';
        case 'opus': return 'audio/opus';
        case 'ape': return 'audio/x-ape';
        case 'wv': return 'audio/x-wv';
        default: return 'application/octet-stream';
      }
    } catch (_) {
      return 'application/octet-stream';
    }
  }

  /// ms → mm:ss（分钟秒数补零）
  static formatTime(ms: number): string {
    const totalSec = Math.floor(ms / 1000);
    const m = Math.floor(totalSec / 60);
    const s = totalSec % 60;
    return `${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
  }

  /// 进度百分比 (value/total)*100 钳制 [min, max]，total<=0 返回 min
  /// 供进度条/圆环进度按钮等共用（PlayHomePage progressPercent / Index miniProgressPercent）
  static clampPct(value: number, total: number, min: number = 0, max: number = 100): number {
    if (total <= 0) return min;
    const p = (value / total) * 100;
    return p < min ? min : (p > max ? max : p);
  }

  /// 总时长格式化（听歌统计/专辑/艺术家共用）：hh:mm:ss 或 mm:ss
  static formatTotalDuration(ms: number): string {
    const totalSec = Math.max(0, Math.floor((ms || 0) / 1000));
    const h = Math.floor(totalSec / 3600);
    const m = Math.floor((totalSec % 3600) / 60);
    const s = totalSec % 60;
    const ss = s.toString().padStart(2, '0');
    if (h > 0) {
      return `${h}:${m.toString().padStart(2, '0')}:${ss}`;
    }
    return `${m}:${ss}`;
  }
}

import AVFoundation

/// Lightweight SFX player for the game's audio feedback.
///
/// All effects are short, pre-decoded `AVAudioPlayer` instances kept in a small pool per sound so
/// rapid, overlapping triggers (e.g. fast tapping, or a level-up firing over taps) don't cut each
/// other off. Playback respects the hardware mute switch via the `.ambient` audio-session category
/// and mixes politely with any background music the player already has going.
///
/// Every clip is an original, OSRS-*inspired* synth cue — no Jagex audio is sampled. Callers gate
/// playback on `GameState.soundEnabled`, mirroring how the views gate `.sensoryFeedback` on
/// `hapticsEnabled`.
@MainActor
final class SoundManager {
    static let shared = SoundManager()

    /// One cue per meaningful game moment. Raw value is the bundled `.wav` file name.
    enum Sound: String, CaseIterable {
        case tap         = "sfx_tap"          // every training tap (core loop)
        case levelUp     = "sfx_levelup"      // a skill gains a level
        case supercharge = "sfx_supercharge"  // spend Energy on a Supercharge burst
        case energyCell  = "sfx_energycell"   // fill the trained skill with an Energy Cell
        case doubleXP    = "sfx_doublexp"     // activate a Daily Boost coupon
        case purchase    = "sfx_purchase"     // an IAP grant lands
        case ui          = "sfx_ui"           // interface navigation (open a panel)

        /// Per-cue trim so the palette sits at a consistent perceived loudness — the bright
        /// short cues (tap/ui) are pulled down, the fuller cues sit a touch below unity.
        var volume: Float {
            switch self {
            case .tap:         return 0.85
            case .ui:          return 0.6
            case .levelUp:     return 0.7
            case .supercharge: return 0.9
            case .energyCell:  return 0.85
            case .doubleXP:    return 0.9
            case .purchase:    return 0.9
            }
        }

        /// How many overlapping voices to pre-allocate. The tap fires fastest, so it gets more.
        var poolSize: Int { self == .tap ? 5 : 2 }
    }

    private var pools: [Sound: [AVAudioPlayer]] = [:]
    private var nextVoice: [Sound: Int] = [:]
    private var sessionReady = false

    private init() { preload() }

    /// Warm up the players and audio session at launch so the first tap has no decode hitch.
    func prepare() {
        activateSession()
        for pool in pools.values { pool.forEach { $0.prepareToPlay() } }
    }

    /// Play a cue if `enabled`. Picks a free voice from the sound's pool (round-robins if all are
    /// busy) so overlapping triggers layer instead of clipping each other.
    func play(_ sound: Sound, enabled: Bool) {
        guard enabled, let pool = pools[sound], !pool.isEmpty else { return }
        activateSession()

        let voice = pool.first(where: { !$0.isPlaying }) ?? {
            let i = (nextVoice[sound] ?? 0) % pool.count
            nextVoice[sound] = i + 1
            return pool[i]
        }()

        voice.volume = sound.volume
        voice.currentTime = 0
        voice.play()
    }

    private func preload() {
        for sound in Sound.allCases {
            guard let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "wav") else {
                continue
            }
            var pool: [AVAudioPlayer] = []
            for _ in 0..<sound.poolSize {
                if let player = try? AVAudioPlayer(contentsOf: url) {
                    player.volume = sound.volume
                    player.prepareToPlay()
                    pool.append(player)
                }
            }
            pools[sound] = pool
        }
    }

    private func activateSession() {
        guard !sessionReady else { return }
        sessionReady = true
        let session = AVAudioSession.sharedInstance()
        // `.ambient` keeps us silent under the mute switch and mixes with the player's own music.
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
    }
}

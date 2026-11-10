import Foundation

/// Built-in kaomoji. Raw strings keep the backslashes literal.
enum KaomojiData {
    static let groups: [PickerGroup] = PickerData.makeGroups([
        (title: "Happy", entries: happy),
        (title: "Love", entries: love),
        (title: "Shrug & Confused", entries: confused),
        (title: "Sad", entries: sad),
        (title: "Angry", entries: angry),
        (title: "Animals", entries: animals),
        (title: "Actions", entries: actions)
    ])

    private static func entry(_ value: String, _ keywords: String) -> PickerEntry {
        PickerEntry(value: value, keywords: keywords)
    }

    private static let happy: [PickerEntry] = [
        entry(#"(◕‿◕)"#, "happy smile cute"),
        entry(#"(｡◕‿◕｡)"#, "happy smile cute"),
        entry(#"(＾▽＾)"#, "happy joy laugh"),
        entry(#"(*^‿^*)"#, "happy smile blush"),
        entry(#"(•‿•)"#, "happy smile"),
        entry(#"(ᵔᴥᵔ)"#, "happy cute"),
        entry(#"ヽ(・∀・)ﾉ"#, "happy cheer hooray"),
        entry(#"(ﾉ◕ヮ◕)ﾉ*:･ﾟ✧"#, "happy magic sparkle excited"),
        entry(#"(✿◠‿◠)"#, "happy flower smile"),
        entry(#"(≧◡≦)"#, "happy delighted"),
        entry(#"(´• ω •`)"#, "happy cute soft"),
        entry(#"\(^o^)/"#, "happy hooray yay"),
        entry(#"٩(◕‿◕｡)۶"#, "happy excited yay"),
        entry(#"(ง •̀_•́)ง"#, "determined fight you can do it")
    ]

    private static let love: [PickerEntry] = [
        entry(#"(♥‿♥)"#, "love heart eyes"),
        entry(#"(｡♥‿♥｡)"#, "love heart eyes"),
        entry(#"(づ｡◕‿‿◕｡)づ"#, "love hug"),
        entry(#"(っ◔◡◔)っ ♥"#, "love hug heart"),
        entry(#"(´∀`)♡"#, "love heart happy"),
        entry(#"♡(˃͈ દ ˂͈ ༶ )"#, "love kiss"),
        entry(#"(づ￣ ³￣)づ"#, "love kiss hug"),
        entry(#"(˘³˘)♥"#, "love kiss")
    ]

    private static let confused: [PickerEntry] = [
        entry(#"¯\_(ツ)_/¯"#, "shrug whatever dunno"),
        entry(#"┐(´～｀)┌"#, "shrug whatever"),
        entry(#"ヽ(ー_ー)ノ"#, "shrug whatever"),
        entry(#"(・_・ヾ"#, "confused scratch"),
        entry(#"(⊙_⊙)"#, "surprised shocked stare"),
        entry(#"(°ロ°)"#, "surprised shocked"),
        entry(#"(¬_¬)"#, "skeptical side eye"),
        entry(#"(ಠ_ಠ)"#, "disapproval stare look"),
        entry(#"ಠ‿ಠ"#, "smug look"),
        entry(#"(・・?)"#, "confused question"),
        entry(#"(－‸ლ)"#, "facepalm")
    ]

    private static let sad: [PickerEntry] = [
        entry(#"(╥﹏╥)"#, "sad cry tears"),
        entry(#"(ಥ﹏ಥ)"#, "sad cry tears"),
        entry(#"(；﹏；)"#, "sad cry"),
        entry(#"(｡•́︿•̀｡)"#, "sad pout"),
        entry(#"(っ˘̩╭╮˘̩)っ"#, "sad hug"),
        entry(#"(´；ω；`)"#, "sad cry"),
        entry(#"(T_T)"#, "sad cry"),
        entry(#"(._.)"#, "sad down"),
        entry(#"( ˘･з･)"#, "pout sulk")
    ]

    private static let angry: [PickerEntry] = [
        entry(#"(╯°□°)╯︵ ┻━┻"#, "table flip angry rage"),
        entry(#"┬─┬ノ( º _ ºノ)"#, "table put back calm"),
        entry(#"(ノಠ益ಠ)ノ彡┻━┻"#, "table flip angry rage"),
        entry(#"(ಠ益ಠ)"#, "angry rage"),
        entry(#"(╬ ಠ益ಠ)"#, "angry furious"),
        entry(#"ヽ(`Д´)ﾉ"#, "angry yell"),
        entry(#"(｀へ´)"#, "angry grumpy"),
        entry(#"୧༼ಠ益ಠ༽୨"#, "angry fists")
    ]

    private static let animals: [PickerEntry] = [
        entry(#"ʕ•ᴥ•ʔ"#, "bear cute"),
        entry(#"ʕっ•ᴥ•ʔっ"#, "bear hug"),
        entry(#"(=^･ω･^=)"#, "cat kitty"),
        entry(#"(=^‥^=)"#, "cat kitty"),
        entry(#"ฅ^•ﻌ•^ฅ"#, "cat paws"),
        entry(#"(U・ᴥ・U)"#, "dog puppy"),
        entry(#"▼・ᴥ・▼"#, "dog puppy"),
        entry(#"(・⊝・)"#, "bird"),
        entry(#"<コ:彡"#, "squid"),
        entry(#"><(((º>"#, "fish")
    ]

    private static let actions: [PickerEntry] = [
        entry(#"( •_•)>⌐■-■"#, "sunglasses putting on cool"),
        entry(#"(⌐■_■)"#, "sunglasses cool deal with it"),
        entry(#"(☞ﾟヮﾟ)☞"#, "point finger guns"),
        entry(#"☜(ﾟヮﾟ☜)"#, "point finger guns"),
        entry(#"( ͡° ͜ʖ ͡°)"#, "lenny smirk"),
        entry(#"ᕕ( ᐛ )ᕗ"#, "run happy walk"),
        entry(#"ᕙ(⇀‸↼‶)ᕗ"#, "flex strong"),
        entry(#"♪~ ᕕ(ᐛ)ᕗ"#, "music dance walk"),
        entry(#"┏(＾0＾)┛"#, "dance"),
        entry(#"(～￣▽￣)～"#, "dance wave"),
        entry(#"(－_－) zzZ"#, "sleep tired"),
        entry(#"m(_ _)m"#, "bow sorry thanks"),
        entry(#"(*・ω・)ﾉ"#, "wave hello hi"),
        entry(#"(^_^)/~~"#, "wave bye goodbye")
    ]
}

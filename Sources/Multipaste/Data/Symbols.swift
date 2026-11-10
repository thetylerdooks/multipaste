import Foundation

/// Built-in symbols, one per line: the symbol, a space, then search keywords.
enum SymbolData {
    static let groups: [PickerGroup] = PickerData.makeGroups([
        (title: "Arrows", entries: PickerData.parse(arrows)),
        (title: "Math", entries: PickerData.parse(math)),
        (title: "Currency", entries: PickerData.parse(currency)),
        (title: "Marks & Punctuation", entries: PickerData.parse(marks)),
        (title: "Stars & Shapes", entries: PickerData.parse(shapes)),
        (title: "Bullets", entries: PickerData.parse(bullets)),
        (title: "Check Marks", entries: PickerData.parse(checks)),
        (title: "Keyboard", entries: PickerData.parse(keyboard)),
        (title: "Greek", entries: PickerData.parse(greek))
    ])

    private static let arrows = """
    ← left arrow
    → right arrow
    ↑ up arrow
    ↓ down arrow
    ↔ left right arrow
    ↕ up down arrow
    ↖ up left arrow
    ↗ up right arrow
    ↘ down right arrow
    ↙ down left arrow
    ⇐ double left arrow
    ⇒ double right arrow implies
    ⇑ double up arrow
    ⇓ double down arrow
    ⇔ double left right arrow iff
    ⟵ long left arrow
    ⟶ long right arrow
    ➜ heavy right arrow
    ➔ heavy right arrow
    ➤ arrowhead right
    ↩ return left hook arrow
    ↪ right hook arrow
    ↻ clockwise redo arrow
    ↺ counterclockwise undo arrow
    ▲ triangle up
    ▼ triangle down
    ◀ triangle left
    ▶ triangle right play
    """

    private static let math = """
    ± plus minus
    × multiply times
    ÷ divide
    ≠ not equal
    ≈ approximately almost equal
    ≡ identical equivalent
    ≤ less than or equal
    ≥ greater than or equal
    ∞ infinity
    √ square root
    ∑ sum sigma
    ∏ product pi
    ∫ integral
    ∂ partial derivative
    ∆ delta increment
    ∇ nabla gradient
    ∈ element of
    ∉ not element of
    ∩ intersection
    ∪ union
    ⊂ subset
    ⊃ superset
    ∅ empty set
    ∴ therefore
    ∝ proportional
    ° degree
    ′ prime minutes feet
    ″ double prime seconds inches
    ‰ per mille
    ½ one half fraction
    ⅓ one third fraction
    ¼ one quarter fraction
    ¾ three quarters fraction
    ¹ superscript one
    ² superscript two squared
    ³ superscript three cubed
    µ micro
    """

    private static let currency = """
    $ dollar
    € euro
    £ pound sterling
    ¥ yen yuan
    ¢ cent
    ₹ rupee
    ₽ ruble
    ₩ won
    ₪ shekel
    ₫ dong
    ₺ lira
    ₴ hryvnia
    ₦ naira
    ฿ baht
    ₿ bitcoin
    ¤ generic currency
    """

    private static let marks = """
    ™ trademark tm
    © copyright
    ® registered
    ℠ service mark
    § section
    ¶ paragraph pilcrow
    † dagger
    ‡ double dagger
    № numero number
    ℃ celsius degree
    ℉ fahrenheit degree
    … ellipsis
    – en dash
    — em dash
    « left guillemet quote
    » right guillemet quote
    ‹ single left guillemet
    › single right guillemet
    “ left double quote
    ” right double quote
    ‘ left single quote
    ’ right single quote apostrophe
    ¿ inverted question
    ¡ inverted exclamation
    """

    private static let shapes = """
    ★ black star
    ☆ white star
    ✦ four pointed star
    ✧ white four pointed star
    ✪ circled star
    ✯ pinwheel star
    ♥ black heart
    ♡ white heart
    ♦ diamond suit
    ♣ club suit
    ♠ spade suit
    ♪ music note
    ♫ music notes
    ☀ sun
    ☁ cloud
    ☂ umbrella
    ☃ snowman
    ☾ moon
    ☮ peace
    ☯ yin yang
    ⚑ black flag
    ⚐ white flag
    ■ black square
    □ white square
    ▪ small black square
    ▫ small white square
    ● black circle
    ○ white circle
    ◆ black diamond
    ◇ white diamond
    ▢ rounded square
    """

    private static let bullets = """
    • bullet
    ◦ white bullet
    ‣ triangular bullet
    ⁃ hyphen bullet
    ∙ bullet operator
    · middle dot interpunct
    ⁌ leftwards bullet
    ⁍ rightwards bullet
    ❖ diamond bullet
    ➢ arrowhead bullet
    ➣ arrowhead bullet
    ⦿ circled bullet
    ⦾ circled white bullet
    """

    private static let checks = """
    ✓ check mark tick
    ✔ heavy check mark tick
    ✗ ballot x cross
    ✘ heavy ballot x cross
    ☐ ballot box empty checkbox
    ☑ ballot box check checkbox
    ☒ ballot box x checkbox
    ✕ multiplication x cross
    ✖ heavy x cross
    """

    private static let keyboard = """
    ⌘ command cmd
    ⌥ option alt
    ⇧ shift
    ⌃ control ctrl
    ⎋ escape esc
    ⇥ tab
    ⇪ caps lock
    ↩ return enter
    ⏎ return enter
    ⌫ delete backspace
    ⌦ forward delete
    ␣ space
    ⏏ eject
    """

    private static let greek = """
    α alpha
    β beta
    γ gamma
    δ delta
    ε epsilon
    ζ zeta
    η eta
    θ theta
    ι iota
    κ kappa
    λ lambda
    μ mu
    ν nu
    ξ xi
    ο omicron
    π pi
    ρ rho
    σ sigma
    τ tau
    υ upsilon
    φ phi
    χ chi
    ψ psi
    ω omega
    Γ capital gamma
    Δ capital delta
    Θ capital theta
    Λ capital lambda
    Ξ capital xi
    Π capital pi
    Σ capital sigma
    Φ capital phi
    Ψ capital psi
    Ω capital omega
    """
}

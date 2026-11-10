import Foundation

/// Built-in emoji, one per line: the emoji, a space, then search keywords.
enum EmojiData {
    static let groups: [PickerGroup] = PickerData.makeGroups([
        (title: "Smileys", entries: PickerData.parse(smileys)),
        (title: "People & Gestures", entries: PickerData.parse(people)),
        (title: "Hearts & Signs", entries: PickerData.parse(hearts)),
        (title: "Animals & Nature", entries: PickerData.parse(nature)),
        (title: "Food & Drink", entries: PickerData.parse(food)),
        (title: "Activities", entries: PickerData.parse(activities)),
        (title: "Travel & Places", entries: PickerData.parse(travel)),
        (title: "Objects", entries: PickerData.parse(objects))
    ])

    private static let smileys = """
    😀 grinning face happy smile
    😃 smiley happy joy
    😄 smile happy laugh
    😁 grin beaming teeth
    😆 laughing squint haha
    😅 sweat smile relief nervous
    🤣 rofl rolling floor laughing
    😂 joy tears laugh crying
    🙂 slight smile
    🙃 upside down sarcasm
    😉 wink
    😊 blush smile happy
    😇 innocent angel halo
    🥰 love hearts adore
    😍 heart eyes love
    🤩 star struck excited
    😘 kiss blow heart
    😗 kissing
    😚 kissing closed eyes
    😋 yum delicious tongue
    😛 tongue out
    😜 wink tongue crazy
    🤪 zany goofy crazy
    😝 squint tongue
    🤑 money face rich
    🤗 hug hugging
    🤭 hand over mouth oops giggle
    🤫 shush quiet secret
    🤔 thinking hmm
    🤐 zipper mouth secret
    🤨 raised eyebrow skeptical
    😐 neutral
    😑 expressionless
    😶 no mouth silent
    😏 smirk
    😒 unamused
    🙄 eye roll
    😬 grimace awkward
    😌 relieved calm
    😔 pensive sad
    😪 sleepy
    🤤 drool
    😴 sleeping zzz
    😷 mask sick
    🤒 thermometer sick fever
    🤕 bandage hurt
    🤢 nauseated sick green
    🤮 vomit sick
    🤧 sneeze tissue
    🥵 hot sweating
    🥶 cold freezing
    🥴 woozy dizzy drunk
    😵 dizzy knocked out
    🤯 mind blown exploding head
    🤠 cowboy hat
    🥳 party celebrate birthday
    😎 cool sunglasses
    🤓 nerd glasses
    🧐 monocle curious
    😕 confused
    😟 worried
    🙁 frown sad
    😮 surprised open mouth wow
    😯 hushed
    😲 astonished shocked
    😳 flushed embarrassed
    🥺 pleading puppy eyes
    😦 frowning open mouth
    😨 fearful scared
    😰 anxious sweat
    😥 sad relieved
    😢 cry tear sad
    😭 sob crying loud
    😱 scream fear
    😖 confounded
    😣 persevere
    😞 disappointed
    😓 downcast sweat
    😩 weary tired
    😫 tired exhausted
    🥱 yawn bored
    😤 huff triumph steam
    😡 pout angry rage
    😠 angry mad
    🤬 cursing swearing
    😈 devil smile horns
    👿 devil angry imp
    💀 skull dead
    💩 poop
    🤡 clown
    👻 ghost boo
    👽 alien
    🤖 robot
    😺 cat smile
    😸 cat grin
    😹 cat joy
    😻 cat heart eyes
    🙈 see no evil monkey
    🙉 hear no evil monkey
    🙊 speak no evil monkey
    """

    private static let people = """
    👋 wave hello bye
    🤚 raised back hand
    ✋ hand stop high five
    🖖 vulcan spock
    👌 ok okay perfect
    🤌 pinched fingers italian
    🤏 pinch small
    ✌️ peace victory
    🤞 fingers crossed luck
    🤟 love you gesture
    🤘 rock on horns
    🤙 call me shaka
    👈 point left
    👉 point right
    👆 point up
    👇 point down
    ☝️ index up one
    👍 thumbs up like yes
    👎 thumbs down dislike no
    ✊ fist raised
    👊 fist bump punch
    🤛 left fist
    🤜 right fist
    👏 clap applause
    🙌 raised hands hooray
    👐 open hands
    🤲 palms up
    🤝 handshake deal
    🙏 pray thanks please
    ✍️ writing hand
    💅 nail polish
    🤳 selfie
    💪 muscle strong flex
    🧠 brain
    👀 eyes look
    👁️ eye
    👅 tongue
    👄 lips mouth
    👶 baby
    🧒 child
    👦 boy
    👧 girl
    🧑 person adult
    👨 man
    👩 woman
    🧓 older person
    👴 old man
    👵 old woman
    🙋 raising hand
    🤦 facepalm
    🤷 shrug
    🙅 no gesture
    🙆 ok gesture
    💁 info tipping hand
    🧑‍💻 technologist coder developer
    🕵️ detective
    👮 police officer
    👷 construction worker
    🤴 prince
    👸 princess
    🦸 superhero
    🧙 mage wizard
    🧟 zombie
    💃 dancer woman dancing
    🕺 man dancing
    🚶 walking
    🏃 running
    👫 couple
    👪 family
    """

    private static let hearts = """
    ❤️ red heart love
    🧡 orange heart
    💛 yellow heart
    💚 green heart
    💙 blue heart
    💜 purple heart
    🖤 black heart
    🤍 white heart
    🤎 brown heart
    💔 broken heart
    ❣️ heart exclamation
    💕 two hearts
    💞 revolving hearts
    💓 beating heart
    💗 growing heart
    💖 sparkling heart
    💘 heart arrow cupid
    💝 heart ribbon gift
    💯 hundred perfect score
    💢 anger
    💥 boom collision
    💫 dizzy star
    💦 sweat droplets
    💨 dash wind
    💬 speech bubble
    💭 thought bubble
    💤 zzz sleep
    ✨ sparkles
    ⭐ star
    🌟 glowing star
    🔥 fire hot lit
    🎉 party popper tada celebrate
    🎊 confetti
    ✅ check mark done
    ❌ cross mark no
    ❓ question
    ❗ exclamation
    ‼️ double exclamation
    ⚠️ warning
    🚫 prohibited no
    ⛔ no entry
    ♻️ recycle
    🔴 red circle
    🟠 orange circle
    🟡 yellow circle
    🟢 green circle
    🔵 blue circle
    🟣 purple circle
    ⚫ black circle
    ⚪ white circle
    🔺 red triangle up
    🔻 red triangle down
    ➕ plus
    ➖ minus
    ➗ divide
    ✖️ multiply
    ♾️ infinity
    🔔 bell notification
    🔕 bell muted
    🎵 music note
    🎶 music notes
    🆗 ok button
    🆕 new button
    🆓 free button
    🔝 top
    """

    private static let nature = """
    🐶 dog puppy
    🐱 cat kitten
    🐭 mouse
    🐹 hamster
    🐰 rabbit bunny
    🦊 fox
    🐻 bear
    🐼 panda
    🐨 koala
    🐯 tiger
    🦁 lion
    🐮 cow
    🐷 pig
    🐸 frog
    🐵 monkey
    🐔 chicken
    🐧 penguin
    🐦 bird
    🐤 chick
    🦆 duck
    🦅 eagle
    🦉 owl
    🦇 bat
    🐺 wolf
    🐗 boar
    🐴 horse
    🦄 unicorn
    🐝 bee
    🐛 bug caterpillar
    🦋 butterfly
    🐌 snail
    🐞 ladybug
    🐜 ant
    🕷️ spider
    🐢 turtle
    🐍 snake
    🦖 t-rex dinosaur
    🐙 octopus
    🦀 crab
    🐠 tropical fish
    🐟 fish
    🐬 dolphin
    🐳 whale
    🦈 shark
    🐊 crocodile
    🐘 elephant
    🦒 giraffe
    🐑 sheep
    🐕 dog
    🐈 cat
    🌵 cactus
    🎄 christmas tree
    🌲 evergreen tree
    🌳 tree
    🌴 palm tree
    🌱 seedling sprout
    🌿 herb leaf
    🍀 four leaf clover luck
    🍁 maple leaf autumn
    🍂 fallen leaf
    🌸 cherry blossom
    🌹 rose
    🌺 hibiscus
    🌻 sunflower
    🌼 blossom
    🌷 tulip
    🌞 sun face
    🌝 full moon face
    🌙 crescent moon
    🌎 earth globe world
    ☀️ sun sunny
    ⛅ partly cloudy
    ☁️ cloud
    🌧️ rain
    ⛈️ storm thunder
    🌈 rainbow
    ❄️ snowflake
    ⛄ snowman
    ⚡ lightning zap
    💧 droplet water
    🌊 wave ocean
    """

    private static let food = """
    🍎 red apple
    🍊 orange tangerine
    🍋 lemon
    🍌 banana
    🍉 watermelon
    🍇 grapes
    🍓 strawberry
    🍒 cherries
    🍑 peach
    🥭 mango
    🍍 pineapple
    🥥 coconut
    🥝 kiwi
    🍅 tomato
    🥑 avocado
    🍆 eggplant
    🥦 broccoli
    🥕 carrot
    🌽 corn
    🌶️ chili pepper hot
    🥔 potato
    🍞 bread
    🥐 croissant
    🧀 cheese
    🥚 egg
    🍳 fried egg cooking
    🥓 bacon
    🥞 pancakes
    🍔 burger hamburger
    🍟 fries
    🍕 pizza
    🌭 hot dog
    🥪 sandwich
    🌮 taco
    🌯 burrito
    🍝 spaghetti pasta
    🍜 ramen noodles
    🍣 sushi
    🍱 bento
    🍚 rice
    🍿 popcorn
    🍩 donut
    🍪 cookie
    🎂 birthday cake
    🍰 cake slice
    🧁 cupcake
    🍫 chocolate
    🍬 candy
    🍭 lollipop
    🍦 ice cream
    ☕ coffee hot drink
    🍵 tea
    🥤 soda cup straw
    🧃 juice box
    🍺 beer
    🍻 cheers beers
    🥂 champagne toast
    🍷 wine
    🍸 cocktail
    🍹 tropical drink
    🥃 whisky
    🍾 champagne bottle
    """

    private static let activities = """
    ⚽ soccer football
    🏀 basketball
    🏈 american football
    ⚾ baseball
    🎾 tennis
    🏐 volleyball
    🏉 rugby
    🎱 pool 8 ball
    🏓 ping pong
    🏸 badminton
    🥊 boxing glove
    ⛳ golf
    🏒 hockey
    🎿 ski
    🏂 snowboard
    🏋️ weight lifting gym
    🚴 cycling bike
    🏊 swimming
    🧘 yoga meditate
    🏆 trophy win
    🥇 gold medal first
    🥈 silver medal second
    🥉 bronze medal third
    🏅 medal
    🎯 dart target bullseye
    🎮 video game controller
    🎲 dice
    🧩 puzzle
    ♟️ chess pawn
    🎨 art palette paint
    🎬 clapper movie
    🎤 microphone sing
    🎧 headphones
    🎸 guitar
    🎹 piano keyboard
    🥁 drum
    🎺 trumpet
    🎻 violin
    🎭 theater masks
    🎪 circus
    🎁 gift present
    🎈 balloon
    🎃 pumpkin halloween
    """

    private static let travel = """
    🚗 car
    🚕 taxi
    🚌 bus
    🚓 police car
    🚑 ambulance
    🚒 fire engine
    🚚 truck delivery
    🚜 tractor
    🏎️ race car
    🏍️ motorcycle
    🚲 bicycle bike
    🛴 scooter
    ✈️ airplane flight
    🚀 rocket launch
    🛸 ufo
    🚁 helicopter
    ⛵ sailboat
    🚢 ship
    🚂 train locomotive
    🚇 metro subway
    ⚓ anchor
    ⛽ fuel gas
    🚦 traffic light
    🗺️ map
    🧭 compass
    🏠 house home
    🏢 office building
    🏥 hospital
    🏦 bank
    🏫 school
    🏰 castle
    🗽 statue of liberty
    🗼 tokyo tower
    🏝️ island
    🏖️ beach
    ⛰️ mountain
    🏕️ camping
    🌋 volcano
    🌅 sunrise
    🌃 night city
    🎡 ferris wheel
    🎢 roller coaster
    """

    private static let objects = """
    ⌚ watch
    📱 phone mobile
    💻 laptop computer
    ⌨️ keyboard
    🖥️ desktop computer
    🖨️ printer
    🖱️ mouse computer
    💾 floppy disk save
    💿 cd disc
    📷 camera
    📹 video camera
    📺 tv television
    📻 radio
    ⏰ alarm clock
    ⏳ hourglass
    🔋 battery
    🔌 plug
    💡 light bulb idea
    🔦 flashlight
    🕯️ candle
    💸 money wings
    💵 dollar bill
    💳 credit card
    💎 gem diamond
    🔧 wrench
    🔨 hammer
    🛠️ tools
    ⚙️ gear settings
    🔩 nut bolt
    🧲 magnet
    💣 bomb
    🛡️ shield
    🔮 crystal ball
    💊 pill
    💉 syringe
    🧬 dna
    🔬 microscope
    🔭 telescope
    🧹 broom
    🧼 soap
    🔑 key
    🔒 lock locked
    🔓 unlocked
    🚪 door
    🛏️ bed
    🛒 shopping cart
    🎒 backpack
    👓 glasses
    👑 crown
    💍 ring
    👟 sneaker shoe
    📦 package box
    ✉️ envelope mail
    📧 email
    📝 memo note
    📄 document page
    📊 bar chart
    📈 chart up
    📉 chart down
    📅 calendar
    📌 pushpin
    📎 paperclip
    ✂️ scissors
    📏 ruler
    🗑️ trash
    📁 folder
    📋 clipboard
    📚 books
    📖 open book
    🔗 link
    🔍 search magnifying glass
    🏷️ label tag
    🚩 red flag
    🏁 checkered flag finish
    🏳️ white flag
    🏴 black flag
    """
}

extends Control

const _LeaderView := preload("res://leader_view.gd")
const GOLD_COLOR := Color(0.95, 0.78, 0.34)
const PANEL := Color(0.025, 0.045, 0.08, 0.97)
const SAVE_PATH := "user://journeys_dawn_profile.cfg"

# Several call sites (begin_story_stage, begin_challenge, launch_trial_battle)
# only set a handful of "pending reward" keys on the shared profile file
# before saving it straight back. ConfigFile.save() serializes only what's
# currently loaded in memory, so if load() fails on a file that actually
# exists -- corrupted or partially written, most often from the app being
# killed mid-save on mobile -- saving anyway would silently erase every
# other saved field, including academy.complete, and send the player back
# into the tutorial on every future match with no way out. Use this instead
# of "ConfigFile.new(); cfg.load(SAVE_PATH)" at any such partial-write site.
# Returns null when it's unsafe to save; a genuinely missing file (first run,
# before any profile has ever been saved) is still fine to proceed with
# defaults.
func _load_profile_cfg_for_partial_write() -> ConfigFile:
    var cfg := ConfigFile.new()
    var err := cfg.load(SAVE_PATH)
    if err != OK and FileAccess.file_exists(SAVE_PATH):
        return null
    return cfg
const APP_VERSION := "0.5.7"
const BUILD_NAME := "v0.9.3 • BATTLE PREP OVERHAUL"
const CLASSES := ["Hope", "Courage", "Serenity", "Purpose"]
const RARITIES := ["Bronze", "Silver", "Gold", "Epic", "Legendary", "Signature Platinum"]
# Total interactive Academy tutorial lessons. Kept as one const instead of a
# scattered literal "8" so lesson_titles/mentors/tracker/step-count all stay
# in sync when a lesson is added or removed.
const ACADEMY_LESSON_COUNT := 11
# Each leader's real Signature Platinum "special card" -- the closest true
# analog to a leader-defining card in this game's data, used by the Academy's
# leader-showcase lesson. Purpose additionally has the game's only real
# Amulet-type card (Daily Progress, JD-054), taught separately.
const LEADER_SIGNATURE_CARD_IDS := {"Hope": "JD-015", "Courage": "JD-030", "Serenity": "JD-045", "Purpose": "JD-060"}
# One representative card per keyword mechanic, for the Academy's card-effects
# lesson. Picked for having the cleanest, least-cluttered effect text so the
# keyword's meaning reads clearly on its own.
const KEYWORD_EXAMPLE_CARDS := [
    {"keyword": "Arrival", "id": "JD-046", "meaning": "Triggers the moment this card enters play."},
    {"keyword": "Legacy", "id": "JD-086", "meaning": "Triggers when this card is destroyed or sent to the Relapse Zone."},
    {"keyword": "Protector", "id": "JD-083", "meaning": "Enemies must attack this follower before they can attack anything else."},
    {"keyword": "Determination", "id": "JD-089", "meaning": "Rewards this follower for surviving combat."},
    {"keyword": "Breakthrough", "id": "JD-090", "meaning": "Excess combat damage carries through to the enemy leader."},
    {"keyword": "Calm", "id": "JD-032", "meaning": "Rewards you for holding back and not attacking last turn."},
    {"keyword": "Inspire", "id": "JD-082", "meaning": "Triggers whenever another allied follower enters play."},
]
const COPY_LIMITS := {"Bronze":3, "Silver":3, "Gold":3, "Epic":3, "Legendary":2, "Platinum":1, "Signature Gold":2, "Signature Platinum":1}
const MAX_DECK_SLOTS := 8
## IDs that must never appear in an auto-built player deck regardless of ownership.
## JD-080 (The Sponsor) is the only catalog card explicitly banned from player decks.
## Meta / final-boss / dev cards never appear in data/cards.json so they are
## excluded implicitly when the algorithm filters against the catalog.
const AUTO_BUILD_FORBIDDEN_IDS: Array[String] = ["JD-080"]
## One-paragraph playstyle descriptions shown by the "Recommend a Class" branch
## of the Auto-Build class-selection screen.
const AUTO_BUILD_CLASS_BLURBS := {
    "Hope": "Hope decks recover what they've lost. Your leader restores health, fallen followers return from the Relapse Zone, and every card you draw is another chance to outlast whatever the opponent throws at you. If you believe in second chances and want to win by simply refusing to quit, Hope is your class.",
    "Courage": "Courage decks move fast and hit first. Rush and Charge followers land on the board immediately and start dealing damage, you hit the enemy leader directly to build Resolve, and you win before your opponent has time to set up. If you want to be the one driving the pace and putting pressure on from turn one, Courage is your class.",
    "Serenity": "Serenity decks control the board and protect their leader. Protector followers block every threat, Exhaust effects lock down dangerous enemies, and steady healing buys time for your big finishers. If you like thinking two turns ahead and watching your opponent's plans fall apart quietly, Serenity is your class.",
    "Purpose": "Purpose decks invest for the future. Daily Progress amulets grow your maximum PP each game, letting you land game-defining cards earlier than your opponent expects. Every turn you spend all your points moves you closer to Walking Free — a card that ends games. If you want to build toward an unstoppable late game, Purpose is your class."
}
# Per-leader horizontal display shift in pixels applied to the art TextureRect
# inside its clipped container. Negative = move character LEFT in the frame.
# Tune each leader individually until the face / upper body is well-centred.
const LEADER_FOCAL_PX := {"hope": -20, "courage": -55, "serenity": -40, "purpose": -50}
const DUST_VALUES := {"Bronze":12, "Silver":37, "Gold":125, "Epic":625, "Legendary":875, "Platinum":1125, "Signature Platinum":1125}
const CRAFT_COSTS := {"Bronze":50, "Silver":150, "Gold":500, "Epic":2500, "Legendary":3500, "Platinum":4500, "Signature Platinum":4500}
const DAILY_REWARDS := [
    {"packs":1, "vials":0},
    {"packs":2, "vials":0},
    {"packs":3, "vials":0},
    {"packs":4, "vials":0},
    {"packs":4, "vials":300}
]

const CHAPTER_META := [
    {"title":"Hitting Bottom", "subtitle":"Every victory moves the journey forward."},
    {"title":"Building Structure", "subtitle":"Routine and responsibility, one day at a time."},
    {"title":"Repairing What Broke", "subtitle":"The relationships worth fighting for."},
    {"title":"A Life Worth Living", "subtitle":"From surviving to building something that lasts."}
]

# Each leader (Hope, Courage, Serenity, Purpose) plays through its own
# 24-stage story with its own recurring cast, not one shared narrative with a
# swapped-in class. Sponsors are gender-matched to their leader: Hope,
# Courage, and Purpose are men with male sponsors; Serenity is a woman with a
# female sponsor. "class" still drives the actual battle deck; "opponent_name"
# is who the game says you're facing. Chapter beats (hitting bottom, building
# structure, repairing relationships, a life worth living) stay parallel
# across all four so CHAPTER_META and the id/gold/pack pacing can be shared.
const STORY_STAGES_HOPE := [
    # --- Chapter 1: Hitting Bottom — admitting the problem and staying upright ---
    {
        "id":1, "chapter":1, "name":"The First Step", "class":"Hope", "gold":0, "packs":1,
        "opponent_name":"Your Own Doubt",
        "subtitle":"Learn to stay in the fight.",
        "story":"The hardest battle is the one where you finally admit you need to fight at all. Today isn't about winning — it's about showing up and staying in the fight one more round than you thought you could."
    },
    {
        "id":2, "chapter":1, "name":"Finding Strength", "class":"Courage", "gold":150, "packs":0,
        "opponent_name":"Cole",
        "subtitle":"Face pressure without backing down.",
        "story":"Cole finds you when you least expect it — same easy smile, same offer, like nothing's changed. You don't have to be fearless to face him down. You just have to stand your ground long enough to remember you can."
    },
    {
        "id":3, "chapter":1, "name":"Quieting the Noise", "class":"Serenity", "gold":0, "packs":1,
        "opponent_name":"The 2 A.M. Panic",
        "subtitle":"Patience can control the battlefield.",
        "story":"The cravings are loud tonight, but loud isn't the same as strong. You've learned to sit with the noise instead of running from it — and in that stillness, you find you're steadier than it is."
    },
    {
        "id":4, "chapter":1, "name":"A Reason to Continue", "class":"Purpose", "gold":250, "packs":0,
        "opponent_name":"The Old Excuse",
        "subtitle":"Build toward something greater.",
        "story":"Somewhere along the way, recovery stopped being about what you were running from and became about what you're building toward. Today you fight for that reason, not away from the old one."
    },
    {
        "id":5, "chapter":1, "name":"Meeting Marcus", "class":"Courage", "gold":180, "packs":0,
        "opponent_name":"Marcus",
        "subtitle":"A sponsor won't carry you, but he won't let you walk alone either.",
        "story":"He doesn't look impressed when you introduce yourself — he's heard every version of this story before. \"I'm not here to save you,\" Marcus says. \"I'm here so you don't have to figure this out by yourself.\" It's not a warm welcome. It's better: it's honest."
    },
    {
        "id":6, "chapter":1, "name":"Community Test", "class":"Courage", "gold":300, "packs":2,
        "opponent_name":"Marcus",
        "subtitle":"Use everything you have learned.",
        "story":"You're not walking this road alone anymore — and now it's your turn to prove that everything you've learned holds up when someone else is counting on you. Marcus watches you work through it without stepping in. Everything you've built comes together here."
    },
    # --- Chapter 2: Building Structure — routine, work, and the first real test of it ---
    {
        "id":7, "chapter":2, "name":"The Job Interview", "class":"Hope", "gold":200, "packs":0,
        "opponent_name":"Denise",
        "subtitle":"Prove you're ready for a second chance.",
        "story":"Denise can't see the road that got you to her waiting room, and you're not asking her to forget it — you're asking her to bet on who you're becoming. Walk in like you already believe it."
    },
    {
        "id":8, "chapter":2, "name":"First Paycheck", "class":"Courage", "gold":0, "packs":1,
        "opponent_name":"The Old Temptation",
        "subtitle":"Old habits look different with money in your pocket.",
        "story":"There's a version of tonight where this money disappears by morning, same as it always did. Instead you're doing the boring, unglamorous thing — rent, groceries, savings — and it feels more like victory than anything ever did."
    },
    {
        "id":9, "chapter":2, "name":"The Apartment", "class":"Serenity", "gold":220, "packs":0,
        "opponent_name":"The Empty Silence",
        "subtitle":"A door of your own to lock behind you.",
        "story":"It's small, and the faucet drips, and none of that matters. For the first time in longer than you can admit, you have a space that's just yours — quiet enough to hear yourself think, and steady enough to build on."
    },
    {
        "id":10, "chapter":2, "name":"Showing Up Sober", "class":"Purpose", "gold":270, "packs":0,
        "opponent_name":"Denise",
        "subtitle":"Consistency becomes your new reputation.",
        "story":"Ninety days of just... showing up. On time, clear-headed, doing the work. Denise stopped watching you like you might disappear. Reliability isn't glamorous, but it's rewriting what she expects from you."
    },
    {
        "id":11, "chapter":2, "name":"Cole Comes Knocking", "class":"Courage", "gold":300, "packs":0,
        "opponent_name":"Cole",
        "subtitle":"He always shows up right when things start going well.",
        "story":"He heard about the apartment, heard about the job, and somehow that's exactly what brought him around. \"Look at you,\" Cole says, like it's a joke he's in on. It isn't. You've got too much now to hand any of it back to him."
    },
    {
        "id":12, "chapter":2, "name":"The Old Crew", "class":"Courage", "gold":350, "packs":2,
        "opponent_name":"Cole and the Old Crew",
        "subtitle":"Some doors need to stay closed for good.",
        "story":"They wave you over like no time has passed at all. Once, that pull would have owned you. Tonight you keep walking — not out of fear, but because you finally know exactly what you'd be trading away."
    },
    # --- Chapter 3: Repairing What Broke — the relationships worth rebuilding ---
    {
        "id":13, "chapter":3, "name":"The First Call Home", "class":"Hope", "gold":300, "packs":0,
        "opponent_name":"Vanessa",
        "subtitle":"Some bridges take more than one phone call to rebuild.",
        "story":"Your hand hovers over Vanessa's name for a full minute before you finally press call. The conversation is short, careful, and a little awkward — and it's also the first real thread back to a sister you thought you'd burned for good."
    },
    {
        "id":14, "chapter":3, "name":"Sitting With the Guilt", "class":"Serenity", "gold":0, "packs":1,
        "opponent_name":"The Weight of the Past",
        "subtitle":"You can't outrun what you have to make right.",
        "story":"The guilt shows up uninvited, the way it always does at 2 a.m. You don't drown it out this time. You sit with it, let it say its piece, and remind yourself that feeling it is proof you've changed, not evidence you haven't."
    },
    {
        "id":15, "chapter":3, "name":"Making Amends", "class":"Purpose", "gold":320, "packs":0,
        "opponent_name":"Vanessa",
        "subtitle":"An apology only means something if it comes with change.",
        "story":"You don't ask Vanessa to forgive you — that's not yours to demand. You just say the true thing, own every part of it, and show up differently starting today. Whatever she does with it next is hers to decide."
    },
    {
        "id":16, "chapter":3, "name":"Sparring With Marcus", "class":"Courage", "gold":340, "packs":0,
        "opponent_name":"Marcus",
        "subtitle":"Growth stings more coming from someone who actually believes in you.",
        "story":"Marcus doesn't sugarcoat it: you've been avoiding this apology for weeks. \"Comfortable isn't the same as healed,\" he says, and pushes you toward the hardest conversation on your list instead of letting you circle it any longer."
    },
    {
        "id":17, "chapter":3, "name":"Earning Back Trust", "class":"Courage", "gold":380, "packs":0,
        "opponent_name":"Marcus",
        "subtitle":"Trust rebuilds slow, one kept promise at a time.",
        "story":"They still flinch a little when you say 'I promise.' Fair enough — you taught them to. So you keep the small ones: the phone call you said you'd make, the ride you said you'd give. Marcus just watches, the way a sponsor does when he already knows you'll follow through."
    },
    {
        "id":18, "chapter":3, "name":"Family Dinner", "class":"Purpose", "gold":450, "packs":3,
        "opponent_name":"The Whole Family",
        "subtitle":"The whole table, together, for the first time in years.",
        "story":"Nobody says it out loud, but everyone at this table knows what it took to get here. No blowups, no old arguments dragged back out — just plates passed around and easy laughter, like the family you always wanted to give them back."
    },
    # --- Chapter 4: A Life Worth Living — from surviving to building something that lasts ---
    {
        "id":19, "chapter":4, "name":"One Year Coin", "class":"Hope", "gold":400, "packs":0,
        "opponent_name":"The Person You Used to Be",
        "subtitle":"A year ago you couldn't picture this day.",
        "story":"They put the coin in your hand and the room claps, and for a second you're back at day one, certain you'd never make it this far. You did. Not perfectly, not painlessly — but you did. Today you fight for year two."
    },
    {
        "id":20, "chapter":4, "name":"The Promotion", "class":"Purpose", "gold":0, "packs":1,
        "opponent_name":"Denise",
        "subtitle":"They didn't hire the person you used to be.",
        "story":"Denise slides the offer letter across the desk like it's no big deal, but it is — this is trust you built one shift at a time, not luck. She's not betting on the story you used to tell about yourself. She's betting on this one."
    },
    {
        "id":21, "chapter":4, "name":"A Place to Grow", "class":"Serenity", "gold":420, "packs":0,
        "opponent_name":"The Fear of Roots",
        "subtitle":"Roots, finally, instead of just a roof.",
        "story":"The keys feel heavier than they should for something so small. This isn't just a home — it's the first place you've ever planted something and expected to still be there to see it grow."
    },
    {
        "id":22, "chapter":4, "name":"One Last Offer", "class":"Courage", "gold":460, "packs":0,
        "opponent_name":"Cole",
        "subtitle":"This time it isn't even close.",
        "story":"Cole tries the same line one more time, like nothing about you has changed. Nothing about the offer has either — same dead end, same old cost. This time you don't even have to think before you walk away."
    },
    {
        "id":23, "chapter":4, "name":"Becoming a Sponsor", "class":"Courage", "gold":480, "packs":0,
        "opponent_name":"Your First Sponsee",
        "subtitle":"The hand that once pulled you up is now yours to offer.",
        "story":"They're exactly where you were — scared, sure they're the exception nothing can save. You remember every word Marcus once said to steady you, and now you're the one saying it, one first step at a time."
    },
    {
        "id":24, "chapter":4, "name":"Journey's Dawn", "class":"Purpose", "gold":600, "packs":3,
        "opponent_name":"Everything You've Overcome",
        "subtitle":"The story doesn't end here — it just keeps being written.",
        "story":"Nothing, to a job, to a home, to people who trust you again, to being someone else's reason to keep going. This isn't the end of the road. It's proof the road was always worth walking, one day at a time."
    }
]

const STORY_STAGES_COURAGE := [
    {
        "id":1, "chapter":1, "name":"The First Step", "class":"Hope", "gold":0, "packs":1,
        "opponent_name":"Your Own Doubt",
        "subtitle":"Learn to stay in the fight.",
        "story":"You've never been afraid of a hard climb, but this one starts inside your own head. Today isn't about winning — it's about showing up and staying in the fight one more round than you thought you could."
    },
    {
        "id":2, "chapter":1, "name":"Finding Strength", "class":"Courage", "gold":150, "packs":0,
        "opponent_name":"Jonesy",
        "subtitle":"Face pressure without backing down.",
        "story":"Jonesy finds you when you least expect it — same easy smile, same offer, like nothing's changed. You don't have to be fearless to face him down. You just have to stand your ground long enough to remember you can."
    },
    {
        "id":3, "chapter":1, "name":"Quieting the Noise", "class":"Serenity", "gold":0, "packs":1,
        "opponent_name":"The 2 A.M. Panic",
        "subtitle":"Patience can control the battlefield.",
        "story":"The cravings are loud tonight, but loud isn't the same as strong. You've learned to sit with the noise instead of running from it — and in that stillness, you find you're steadier than it is."
    },
    {
        "id":4, "chapter":1, "name":"A Reason to Continue", "class":"Purpose", "gold":250, "packs":0,
        "opponent_name":"The Old Excuse",
        "subtitle":"Build toward something greater.",
        "story":"Somewhere along the way, recovery stopped being about what you were running from and became about what you're building toward. Today you fight for that reason, not away from the old one."
    },
    {
        "id":5, "chapter":1, "name":"Meeting Big Mike", "class":"Courage", "gold":180, "packs":0,
        "opponent_name":"Big Mike",
        "subtitle":"A sponsor won't carry you, but he won't let you walk alone either.",
        "story":"He sizes you up without saying much — he's heard every version of this story before. \"I'm not here to save you,\" Big Mike says. \"I'm here so you don't have to figure this out by yourself.\" It's not a warm welcome. It's better: it's honest."
    },
    {
        "id":6, "chapter":1, "name":"Community Test", "class":"Courage", "gold":300, "packs":2,
        "opponent_name":"Big Mike",
        "subtitle":"Use everything you have learned.",
        "story":"You're not walking this road alone anymore — and now it's your turn to prove that everything you've learned holds up when someone else is counting on you. Big Mike watches you work through it without stepping in. Everything you've built comes together here."
    },
    {
        "id":7, "chapter":2, "name":"The Job Interview", "class":"Hope", "gold":200, "packs":0,
        "opponent_name":"Ms. Patterson",
        "subtitle":"Prove you're ready for a second chance.",
        "story":"Ms. Patterson can't see the road that got you to her waiting room, and you're not asking her to forget it — you're asking her to bet on who you're becoming. Walk in like you already believe it."
    },
    {
        "id":8, "chapter":2, "name":"First Paycheck", "class":"Courage", "gold":0, "packs":1,
        "opponent_name":"The Old Temptation",
        "subtitle":"Old habits look different with money in your pocket.",
        "story":"There's a version of tonight where this money disappears by morning, same as it always did. Instead you're doing the boring, unglamorous thing — rent, groceries, savings — and it feels more like victory than anything ever did."
    },
    {
        "id":9, "chapter":2, "name":"The Apartment", "class":"Serenity", "gold":220, "packs":0,
        "opponent_name":"The Empty Silence",
        "subtitle":"A door of your own to lock behind you.",
        "story":"It's small, and the faucet drips, and none of that matters. For the first time in longer than you can admit, you have a space that's just yours — quiet enough to hear yourself think, and steady enough to build on."
    },
    {
        "id":10, "chapter":2, "name":"Showing Up Sober", "class":"Purpose", "gold":270, "packs":0,
        "opponent_name":"Ms. Patterson",
        "subtitle":"Consistency becomes your new reputation.",
        "story":"Ninety days of just... showing up. On time, clear-headed, doing the work. Ms. Patterson stopped watching you like you might disappear. Reliability isn't glamorous, but it's rewriting what she expects from you."
    },
    {
        "id":11, "chapter":2, "name":"Jonesy Comes Knocking", "class":"Courage", "gold":300, "packs":0,
        "opponent_name":"Jonesy",
        "subtitle":"He always shows up right when things start going well.",
        "story":"He heard about the apartment, heard about the job, and somehow that's exactly what brought him around. \"Look at you,\" Jonesy says, like it's a joke he's in on. It isn't. You've got too much now to hand any of it back to him."
    },
    {
        "id":12, "chapter":2, "name":"The Old Crew", "class":"Courage", "gold":350, "packs":2,
        "opponent_name":"Jonesy and the Old Crew",
        "subtitle":"Some doors need to stay closed for good.",
        "story":"They wave you over like no time has passed at all. Once, that pull would have owned you. Tonight you keep walking — not out of fear, but because you finally know exactly what you'd be trading away."
    },
    {
        "id":13, "chapter":3, "name":"The First Call Home", "class":"Hope", "gold":300, "packs":0,
        "opponent_name":"Andre",
        "subtitle":"Some bridges take more than one phone call to rebuild.",
        "story":"Your hand hovers over Andre's name for a full minute before you finally press call. The conversation is short, careful, and a little awkward — and it's also the first real thread back to a brother you thought you'd burned for good."
    },
    {
        "id":14, "chapter":3, "name":"Sitting With the Guilt", "class":"Serenity", "gold":0, "packs":1,
        "opponent_name":"The Weight of the Past",
        "subtitle":"You can't outrun what you have to make right.",
        "story":"The guilt shows up uninvited, the way it always does at 2 a.m. You don't drown it out this time. You sit with it, let it say its piece, and remind yourself that feeling it is proof you've changed, not evidence you haven't."
    },
    {
        "id":15, "chapter":3, "name":"Making Amends", "class":"Purpose", "gold":320, "packs":0,
        "opponent_name":"Andre",
        "subtitle":"An apology only means something if it comes with change.",
        "story":"You don't ask Andre to forgive you — that's not yours to demand. You just say the true thing, own every part of it, and show up differently starting today. Whatever he does with it next is his to decide."
    },
    {
        "id":16, "chapter":3, "name":"Sparring With Big Mike", "class":"Courage", "gold":340, "packs":0,
        "opponent_name":"Big Mike",
        "subtitle":"Growth stings more coming from someone who actually believes in you.",
        "story":"Big Mike doesn't sugarcoat it: you've been avoiding this apology for weeks. \"Comfortable isn't the same as healed,\" he says, and pushes you toward the hardest conversation on your list instead of letting you circle it any longer."
    },
    {
        "id":17, "chapter":3, "name":"Earning Back Trust", "class":"Courage", "gold":380, "packs":0,
        "opponent_name":"Big Mike",
        "subtitle":"Trust rebuilds slow, one kept promise at a time.",
        "story":"They still flinch a little when you say 'I promise.' Fair enough — you taught them to. So you keep the small ones: the phone call you said you'd make, the ride you said you'd give. Big Mike just watches, the way a sponsor does when he already knows you'll follow through."
    },
    {
        "id":18, "chapter":3, "name":"Family Dinner", "class":"Purpose", "gold":450, "packs":3,
        "opponent_name":"The Whole Family",
        "subtitle":"The whole table, together, for the first time in years.",
        "story":"Nobody says it out loud, but everyone at this table knows what it took to get here. No blowups, no old arguments dragged back out — just plates passed around and easy laughter, like the family you always wanted to give them back."
    },
    {
        "id":19, "chapter":4, "name":"One Year Coin", "class":"Hope", "gold":400, "packs":0,
        "opponent_name":"The Person You Used to Be",
        "subtitle":"A year ago you couldn't picture this day.",
        "story":"They put the coin in your hand and the room claps, and for a second you're back at day one, certain you'd never make it this far. You did. Not perfectly, not painlessly — but you did. Today you fight for year two."
    },
    {
        "id":20, "chapter":4, "name":"The Promotion", "class":"Purpose", "gold":0, "packs":1,
        "opponent_name":"Ms. Patterson",
        "subtitle":"They didn't hire the person you used to be.",
        "story":"Ms. Patterson slides the offer letter across the desk like it's no big deal, but it is — this is trust you built one shift at a time, not luck. She's not betting on the story you used to tell about yourself. She's betting on this one."
    },
    {
        "id":21, "chapter":4, "name":"A Place to Grow", "class":"Serenity", "gold":420, "packs":0,
        "opponent_name":"The Fear of Roots",
        "subtitle":"Roots, finally, instead of just a roof.",
        "story":"The keys feel heavier than they should for something so small. This isn't just a home — it's the first place you've ever planted something and expected to still be there to see it grow."
    },
    {
        "id":22, "chapter":4, "name":"One Last Offer", "class":"Courage", "gold":460, "packs":0,
        "opponent_name":"Jonesy",
        "subtitle":"This time it isn't even close.",
        "story":"Jonesy tries the same line one more time, like nothing about you has changed. Nothing about the offer has either — same dead end, same old cost. This time you don't even have to think before you walk away."
    },
    {
        "id":23, "chapter":4, "name":"Becoming a Sponsor", "class":"Courage", "gold":480, "packs":0,
        "opponent_name":"Your First Sponsee",
        "subtitle":"The hand that once pulled you up is now yours to offer.",
        "story":"They're exactly where you were — scared, sure they're the exception nothing can save. You remember every word Big Mike once said to steady you, and now you're the one saying it, one first step at a time."
    },
    {
        "id":24, "chapter":4, "name":"Journey's Dawn", "class":"Purpose", "gold":600, "packs":3,
        "opponent_name":"Everything You've Overcome",
        "subtitle":"The story doesn't end here — it just keeps being written.",
        "story":"Nothing, to a job, to a home, to people who trust you again, to being someone else's reason to keep going. This isn't the end of the road. It's proof the road was always worth walking, one day at a time."
    }
]

const STORY_STAGES_SERENITY := [
    {
        "id":1, "chapter":1, "name":"The First Step", "class":"Hope", "gold":0, "packs":1,
        "opponent_name":"Your Own Doubt",
        "subtitle":"Learn to stay in the fight.",
        "story":"The hardest battle is the one where you finally admit you need to fight at all. Today isn't about winning — it's about showing up and staying in the fight one more round than you thought you could."
    },
    {
        "id":2, "chapter":1, "name":"Finding Strength", "class":"Courage", "gold":150, "packs":0,
        "opponent_name":"Cass",
        "subtitle":"Face pressure without backing down.",
        "story":"Cass finds you when you least expect it — same easy smile, same offer, like nothing's changed. You don't have to be fearless to face her down. You just have to stand your ground long enough to remember you can."
    },
    {
        "id":3, "chapter":1, "name":"Quieting the Noise", "class":"Serenity", "gold":0, "packs":1,
        "opponent_name":"The 2 A.M. Panic",
        "subtitle":"Patience can control the battlefield.",
        "story":"The cravings are loud tonight, but loud isn't the same as strong. You've learned to sit with the noise instead of running from it — and in that stillness, you find you're steadier than it is."
    },
    {
        "id":4, "chapter":1, "name":"A Reason to Continue", "class":"Purpose", "gold":250, "packs":0,
        "opponent_name":"The Old Excuse",
        "subtitle":"Build toward something greater.",
        "story":"Somewhere along the way, recovery stopped being about what you were running from and became about what you're building toward. Today you fight for that reason, not away from the old one."
    },
    {
        "id":5, "chapter":1, "name":"Meeting Nora", "class":"Courage", "gold":180, "packs":0,
        "opponent_name":"Nora",
        "subtitle":"A sponsor won't carry you, but she won't let you walk alone either.",
        "story":"She doesn't look impressed when you introduce yourself — she's heard every version of this story before. \"I'm not here to save you,\" Nora says. \"I'm here so you don't have to figure this out by yourself.\" It's not a warm welcome. It's better: it's honest."
    },
    {
        "id":6, "chapter":1, "name":"Community Test", "class":"Courage", "gold":300, "packs":2,
        "opponent_name":"Nora",
        "subtitle":"Use everything you have learned.",
        "story":"You're not walking this road alone anymore — and now it's your turn to prove that everything you've learned holds up when someone else is counting on you. Nora watches you work through it without stepping in. Everything you've built comes together here."
    },
    {
        "id":7, "chapter":2, "name":"The Job Interview", "class":"Hope", "gold":200, "packs":0,
        "opponent_name":"Mr. Osei",
        "subtitle":"Prove you're ready for a second chance.",
        "story":"Mr. Osei can't see the road that got you to his waiting room, and you're not asking him to forget it — you're asking him to bet on who you're becoming. Walk in like you already believe it."
    },
    {
        "id":8, "chapter":2, "name":"First Paycheck", "class":"Courage", "gold":0, "packs":1,
        "opponent_name":"The Old Temptation",
        "subtitle":"Old habits look different with money in your pocket.",
        "story":"There's a version of tonight where this money disappears by morning, same as it always did. Instead you're doing the boring, unglamorous thing — rent, groceries, savings — and it feels more like victory than anything ever did."
    },
    {
        "id":9, "chapter":2, "name":"The Apartment", "class":"Serenity", "gold":220, "packs":0,
        "opponent_name":"The Empty Silence",
        "subtitle":"A door of your own to lock behind you.",
        "story":"It's small, and the faucet drips, and none of that matters. For the first time in longer than you can admit, you have a space that's just yours — quiet enough to hear yourself think, and steady enough to build on."
    },
    {
        "id":10, "chapter":2, "name":"Showing Up Sober", "class":"Purpose", "gold":270, "packs":0,
        "opponent_name":"Mr. Osei",
        "subtitle":"Consistency becomes your new reputation.",
        "story":"Ninety days of just... showing up. On time, clear-headed, doing the work. Mr. Osei stopped watching you like you might disappear. Reliability isn't glamorous, but it's rewriting what he expects from you."
    },
    {
        "id":11, "chapter":2, "name":"Cass Comes Knocking", "class":"Courage", "gold":300, "packs":0,
        "opponent_name":"Cass",
        "subtitle":"She always shows up right when things start going well.",
        "story":"She heard about the apartment, heard about the job, and somehow that's exactly what brought her around. \"Look at you,\" Cass says, like it's a joke she's in on. It isn't. You've got too much now to hand any of it back to her."
    },
    {
        "id":12, "chapter":2, "name":"The Old Crew", "class":"Courage", "gold":350, "packs":2,
        "opponent_name":"Cass and the Old Crew",
        "subtitle":"Some doors need to stay closed for good.",
        "story":"They wave you over like no time has passed at all. Once, that pull would have owned you. Tonight you keep walking — not out of fear, but because you finally know exactly what you'd be trading away."
    },
    {
        "id":13, "chapter":3, "name":"The First Call Home", "class":"Hope", "gold":300, "packs":0,
        "opponent_name":"Diane",
        "subtitle":"Some bridges take more than one phone call to rebuild.",
        "story":"Your hand hovers over Diane's name for a full minute before you finally press call. The conversation is short, careful, and a little awkward — and it's also the first real thread back to a mother you thought you'd burned for good."
    },
    {
        "id":14, "chapter":3, "name":"Sitting With the Guilt", "class":"Serenity", "gold":0, "packs":1,
        "opponent_name":"The Weight of the Past",
        "subtitle":"You can't outrun what you have to make right.",
        "story":"The guilt shows up uninvited, the way it always does at 2 a.m. You don't drown it out this time. You sit with it, let it say its piece, and remind yourself that feeling it is proof you've changed, not evidence you haven't."
    },
    {
        "id":15, "chapter":3, "name":"Making Amends", "class":"Purpose", "gold":320, "packs":0,
        "opponent_name":"Diane",
        "subtitle":"An apology only means something if it comes with change.",
        "story":"You don't ask Diane to forgive you — that's not yours to demand. You just say the true thing, own every part of it, and show up differently starting today. Whatever she does with it next is hers to decide."
    },
    {
        "id":16, "chapter":3, "name":"Sparring With Nora", "class":"Courage", "gold":340, "packs":0,
        "opponent_name":"Nora",
        "subtitle":"Growth stings more coming from someone who actually believes in you.",
        "story":"Nora doesn't sugarcoat it: you've been avoiding this apology for weeks. \"Comfortable isn't the same as healed,\" she says, and pushes you toward the hardest conversation on your list instead of letting you circle it any longer."
    },
    {
        "id":17, "chapter":3, "name":"Earning Back Trust", "class":"Courage", "gold":380, "packs":0,
        "opponent_name":"Nora",
        "subtitle":"Trust rebuilds slow, one kept promise at a time.",
        "story":"They still flinch a little when you say 'I promise.' Fair enough — you taught them to. So you keep the small ones: the phone call you said you'd make, the ride you said you'd give. Nora just watches, the way a sponsor does when she already knows you'll follow through."
    },
    {
        "id":18, "chapter":3, "name":"Family Dinner", "class":"Purpose", "gold":450, "packs":3,
        "opponent_name":"The Whole Family",
        "subtitle":"The whole table, together, for the first time in years.",
        "story":"Nobody says it out loud, but everyone at this table knows what it took to get here. No blowups, no old arguments dragged back out — just plates passed around and easy laughter, like the family you always wanted to give them back."
    },
    {
        "id":19, "chapter":4, "name":"One Year Coin", "class":"Hope", "gold":400, "packs":0,
        "opponent_name":"The Person You Used to Be",
        "subtitle":"A year ago you couldn't picture this day.",
        "story":"They put the coin in your hand and the room claps, and for a second you're back at day one, certain you'd never make it this far. You did. Not perfectly, not painlessly — but you did. Today you fight for year two."
    },
    {
        "id":20, "chapter":4, "name":"The Promotion", "class":"Purpose", "gold":0, "packs":1,
        "opponent_name":"Mr. Osei",
        "subtitle":"They didn't hire the person you used to be.",
        "story":"Mr. Osei slides the offer letter across the desk like it's no big deal, but it is — this is trust you built one shift at a time, not luck. He's not betting on the story you used to tell about yourself. He's betting on this one."
    },
    {
        "id":21, "chapter":4, "name":"A Place to Grow", "class":"Serenity", "gold":420, "packs":0,
        "opponent_name":"The Fear of Roots",
        "subtitle":"Roots, finally, instead of just a roof.",
        "story":"The keys feel heavier than they should for something so small. This isn't just a home — it's the first place you've ever planted something and expected to still be there to see it grow."
    },
    {
        "id":22, "chapter":4, "name":"One Last Offer", "class":"Courage", "gold":460, "packs":0,
        "opponent_name":"Cass",
        "subtitle":"This time it isn't even close.",
        "story":"Cass tries the same line one more time, like nothing about you has changed. Nothing about the offer has either — same dead end, same old cost. This time you don't even have to think before you walk away."
    },
    {
        "id":23, "chapter":4, "name":"Becoming a Sponsor", "class":"Courage", "gold":480, "packs":0,
        "opponent_name":"Your First Sponsee",
        "subtitle":"The hand that once pulled you up is now yours to offer.",
        "story":"They're exactly where you were — scared, sure they're the exception nothing can save. You remember every word Nora once said to steady you, and now you're the one saying it, one first step at a time."
    },
    {
        "id":24, "chapter":4, "name":"Journey's Dawn", "class":"Purpose", "gold":600, "packs":3,
        "opponent_name":"Everything You've Overcome",
        "subtitle":"The story doesn't end here — it just keeps being written.",
        "story":"Nothing, to a job, to a home, to people who trust you again, to being someone else's reason to keep going. This isn't the end of the road. It's proof the road was always worth walking, one day at a time."
    }
]

const STORY_STAGES_PURPOSE := [
    {
        "id":1, "chapter":1, "name":"The First Step", "class":"Hope", "gold":0, "packs":1,
        "opponent_name":"Your Own Doubt",
        "subtitle":"Learn to stay in the fight.",
        "story":"The hardest battle is the one where you finally admit you need to fight at all. Today isn't about winning — it's about showing up and staying in the fight one more round than you thought you could."
    },
    {
        "id":2, "chapter":1, "name":"Finding Strength", "class":"Courage", "gold":150, "packs":0,
        "opponent_name":"Trey",
        "subtitle":"Face pressure without backing down.",
        "story":"Trey finds you when you least expect it — same easy smile, same offer, like nothing's changed. You don't have to be fearless to face him down. You just have to stand your ground long enough to remember you can."
    },
    {
        "id":3, "chapter":1, "name":"Quieting the Noise", "class":"Serenity", "gold":0, "packs":1,
        "opponent_name":"The 2 A.M. Panic",
        "subtitle":"Patience can control the battlefield.",
        "story":"The cravings are loud tonight, but loud isn't the same as strong. You've learned to sit with the noise instead of running from it — and in that stillness, you find you're steadier than it is."
    },
    {
        "id":4, "chapter":1, "name":"A Reason to Continue", "class":"Purpose", "gold":250, "packs":0,
        "opponent_name":"The Old Excuse",
        "subtitle":"Build toward something greater.",
        "story":"Somewhere along the way, recovery stopped being about what you were running from and became about what you're building toward — and lately that reason has a name. Today you fight for that, not away from the old one."
    },
    {
        "id":5, "chapter":1, "name":"Meeting Elias", "class":"Courage", "gold":180, "packs":0,
        "opponent_name":"Elias",
        "subtitle":"A sponsor won't carry you, but he won't let you walk alone either.",
        "story":"He doesn't look impressed when you introduce yourself — he's heard every version of this story before. \"I'm not here to save you,\" Elias says. \"I'm here so you don't have to figure this out by yourself.\" It's not a warm welcome. It's better: it's honest."
    },
    {
        "id":6, "chapter":1, "name":"Community Test", "class":"Courage", "gold":300, "packs":2,
        "opponent_name":"Elias",
        "subtitle":"Use everything you have learned.",
        "story":"You're not walking this road alone anymore — and now it's your turn to prove that everything you've learned holds up when someone else is counting on you. Elias watches you work through it without stepping in. Everything you've built comes together here."
    },
    {
        "id":7, "chapter":2, "name":"The Job Interview", "class":"Hope", "gold":200, "packs":0,
        "opponent_name":"Reggie",
        "subtitle":"Prove you're ready for a second chance.",
        "story":"Reggie can't see the road that got you to his waiting room, and you're not asking him to forget it — you're asking him to bet on who you're becoming. Walk in like you already believe it."
    },
    {
        "id":8, "chapter":2, "name":"First Paycheck", "class":"Courage", "gold":0, "packs":1,
        "opponent_name":"The Old Temptation",
        "subtitle":"Old habits look different with money in your pocket.",
        "story":"There's a version of tonight where this money disappears by morning, same as it always did. Instead you're doing the boring, unglamorous thing — rent, groceries, savings — and it feels more like victory than anything ever did."
    },
    {
        "id":9, "chapter":2, "name":"The Apartment", "class":"Serenity", "gold":220, "packs":0,
        "opponent_name":"The Empty Silence",
        "subtitle":"A door of your own to lock behind you.",
        "story":"It's small, and the faucet drips, and none of that matters. For the first time in longer than you can admit, you have a space that's just yours — quiet enough to hear yourself think, and steady enough to build on."
    },
    {
        "id":10, "chapter":2, "name":"Showing Up Sober", "class":"Purpose", "gold":270, "packs":0,
        "opponent_name":"Reggie",
        "subtitle":"Consistency becomes your new reputation.",
        "story":"Ninety days of just... showing up. On time, clear-headed, doing the work. Reggie stopped watching you like you might disappear. Reliability isn't glamorous, but it's rewriting what he expects from you."
    },
    {
        "id":11, "chapter":2, "name":"Trey Comes Knocking", "class":"Courage", "gold":300, "packs":0,
        "opponent_name":"Trey",
        "subtitle":"He always shows up right when things start going well.",
        "story":"He heard about the apartment, heard about the job, and somehow that's exactly what brought him around. \"Look at you,\" Trey says, like it's a joke he's in on. It isn't. You've got too much now to hand any of it back to him."
    },
    {
        "id":12, "chapter":2, "name":"The Old Crew", "class":"Courage", "gold":350, "packs":2,
        "opponent_name":"Trey and the Old Crew",
        "subtitle":"Some doors need to stay closed for good.",
        "story":"They wave you over like no time has passed at all. Once, that pull would have owned you. Tonight you keep walking — not out of fear, but because you finally know exactly what you'd be trading away."
    },
    {
        "id":13, "chapter":3, "name":"The First Call Home", "class":"Hope", "gold":300, "packs":0,
        "opponent_name":"Malik",
        "subtitle":"Some bridges take more than one phone call to rebuild.",
        "story":"Your hand hovers over the number for a full minute before you finally press call. Malik's voice on the other end is careful, a little guarded — and it's also the first real thread back to the son you're determined to show up for."
    },
    {
        "id":14, "chapter":3, "name":"Sitting With the Guilt", "class":"Serenity", "gold":0, "packs":1,
        "opponent_name":"The Weight of the Past",
        "subtitle":"You can't outrun what you have to make right.",
        "story":"The guilt shows up uninvited, the way it always does at 2 a.m. You don't drown it out this time. You sit with it, let it say its piece, and remind yourself that feeling it is proof you've changed, not evidence you haven't."
    },
    {
        "id":15, "chapter":3, "name":"Making Amends", "class":"Purpose", "gold":320, "packs":0,
        "opponent_name":"Malik",
        "subtitle":"An apology only means something if it comes with change.",
        "story":"You don't ask Malik to forgive you — that's not his to owe you. You just say the true thing, own every part of it, and show up differently starting today. Whatever he does with it next is his to decide."
    },
    {
        "id":16, "chapter":3, "name":"Sparring With Elias", "class":"Courage", "gold":340, "packs":0,
        "opponent_name":"Elias",
        "subtitle":"Growth stings more coming from someone who actually believes in you.",
        "story":"Elias doesn't sugarcoat it: you've been avoiding this apology for weeks. \"Comfortable isn't the same as healed,\" he says, and pushes you toward the hardest conversation on your list instead of letting you circle it any longer."
    },
    {
        "id":17, "chapter":3, "name":"Earning Back Trust", "class":"Courage", "gold":380, "packs":0,
        "opponent_name":"Elias",
        "subtitle":"Trust rebuilds slow, one kept promise at a time.",
        "story":"They still flinch a little when you say 'I promise.' Fair enough — you taught them to. So you keep the small ones: the phone call you said you'd make, the ride you said you'd give. Elias just watches, the way a sponsor does when he already knows you'll follow through."
    },
    {
        "id":18, "chapter":3, "name":"Family Dinner", "class":"Purpose", "gold":450, "packs":3,
        "opponent_name":"The Whole Family",
        "subtitle":"The whole table, together, for the first time in years.",
        "story":"Nobody says it out loud, but everyone at this table knows what it took to get here — Malik included. No blowups, no old arguments dragged back out — just plates passed around and easy laughter, like the family you always wanted to give him back."
    },
    {
        "id":19, "chapter":4, "name":"One Year Coin", "class":"Hope", "gold":400, "packs":0,
        "opponent_name":"The Person You Used to Be",
        "subtitle":"A year ago you couldn't picture this day.",
        "story":"They put the coin in your hand and the room claps, and for a second you're back at day one, certain you'd never make it this far. You did. Not perfectly, not painlessly — but you did. Today you fight for year two."
    },
    {
        "id":20, "chapter":4, "name":"The Promotion", "class":"Purpose", "gold":0, "packs":1,
        "opponent_name":"Reggie",
        "subtitle":"They didn't hire the person you used to be.",
        "story":"Reggie slides the offer letter across the desk like it's no big deal, but it is — this is trust you built one shift at a time, not luck. He's not betting on the story you used to tell about yourself. He's betting on this one."
    },
    {
        "id":21, "chapter":4, "name":"A Place to Grow", "class":"Serenity", "gold":420, "packs":0,
        "opponent_name":"The Fear of Roots",
        "subtitle":"Roots, finally, instead of just a roof.",
        "story":"The keys feel heavier than they should for something so small. This isn't just a home — it's the first place you and Malik have ever planted something and expected to still be there to see it grow."
    },
    {
        "id":22, "chapter":4, "name":"One Last Offer", "class":"Courage", "gold":460, "packs":0,
        "opponent_name":"Trey",
        "subtitle":"This time it isn't even close.",
        "story":"Trey tries the same line one more time, like nothing about you has changed. Nothing about the offer has either — same dead end, same old cost. This time you don't even have to think before you walk away."
    },
    {
        "id":23, "chapter":4, "name":"Becoming a Sponsor", "class":"Courage", "gold":480, "packs":0,
        "opponent_name":"Your First Sponsee",
        "subtitle":"The hand that once pulled you up is now yours to offer.",
        "story":"They're exactly where you were — scared, sure they're the exception nothing can save. You remember every word Elias once said to steady you, and now you're the one saying it, one first step at a time."
    },
    {
        "id":24, "chapter":4, "name":"Journey's Dawn", "class":"Purpose", "gold":600, "packs":3,
        "opponent_name":"Everything You've Overcome",
        "subtitle":"The story doesn't end here — it just keeps being written.",
        "story":"Nothing, to a job, to a home, to Malik trusting you again, to being someone else's reason to keep going. This isn't the end of the road. It's proof the road was always worth walking, one day at a time."
    }
]

const STORY_STAGES_BY_LEADER := {
    "Hope": STORY_STAGES_HOPE,
    "Courage": STORY_STAGES_COURAGE,
    "Serenity": STORY_STAGES_SERENITY,
    "Purpose": STORY_STAGES_PURPOSE,
}

const TRIAL_GOLD_REWARDS := {1: 50, 2: 90, 3: 150, 4: 400}
const CHALLENGES := [
    {"name":"Hope Mentor", "class":"Hope", "reward":25, "stars":"★"},
    {"name":"Courage Veteran", "class":"Courage", "reward":40, "stars":"★★"},
    {"name":"Serenity Guardian", "class":"Serenity", "reward":60, "stars":"★★★"},
    {"name":"Purpose Champion", "class":"Purpose", "reward":80, "stars":"★★★★"},
    {"name":"Recovery Master", "class":"All Classes", "reward":150, "stars":"★★★★★"}
]

var root_layer: Control
var cards: Array = []
var gold_balance := 0
var dust_balance := 0
var pack_inventory := 0
var packs_opened := 0
var platinum_pity := 0
var legendary_pity := 0   # cards drawn since last Legendary-or-better; resets on Legendary/Platinum
var selected_class := ""
var collection_owned: Dictionary = {}
var collection_shiny_owned: Dictionary = {}  # card_id -> shiny copy count (draw-only, no crafting)
# Card art is resolved by the CardArt autoload (card_art.gd) — one shared
# function for every screen.  No local art cache or loader lives here.
var saved_deck: Array = []
var saved_decks: Dictionary = {}
var recovery_challenge_progress: Dictionary = {}
var challenge_week_key: String = ""  # ISO week bucket; resets progress when the week rolls over
# The Trials: repeatable PvE gauntlet. trials_cleared keys are "<Class>_<tier>"
# (tier 1-3) or "Sponsor_4" for the bonus boss. Cosmetic rewards are separate
# flags since they persist even if sponsor_defeated bookkeeping ever changes.
var trials_cleared: Dictionary = {}
var sponsor_leader_unlocked := false
var sponsor_sleeve_unlocked := false
var owned_sleeves: Array = []   # Array of sleeve IDs earned from packs/purchases
var equipped_sleeve: String = ""  # Active sleeve ID; "" = class default
var sponsor_defeated := false
var selected_leader_skin := "" # "" (normal) or "sponsor"
var trial_select_class := "Hope"
var selected_deck_class := "Hope"
# ── Multi-deck slots ─────────────────────────────────────────────────────────
# Array of Dicts: { "name": String, "class": String, "cards": Array[String] }
# Up to MAX_DECK_SLOTS entries.  Index -1 = "use prebuilt starter deck".
var deck_slots: Array = []
var last_trial_deck_idx: int = -1     # which slot the player last chose for Trials
var last_battle_deck_idx: int = -1    # which slot the player last chose for Battles
var editing_deck_slot_idx: int = -1   # set while deck builder is open for a specific slot
# Collection screen filter state -- "All" plus the four leader classes plus
# "Neutral" for the class tabs, "All" plus each rarity name for the rarity
# tabs. Kept as instance vars (not locals) so re-opening the screen after a
# craft/dust action remembers what the player was looking at.
var collection_filter_class := "All"
var collection_filter_rarity := "All"
var collection_search_query := ""
var _collection_focus_search_next := false
# Deck Builder filter state — persists across filter interactions within a session.
var _db_owned_only    := false
var _db_cost_filter   := -1    # -1 = all costs; 7 = "7+"
var _db_rarity_filter := ""    # "" = all rarities
var _db_type_filter   := ""    # "" = all types
var _db_search_text   := ""
# When true, the collection/crafting binder only shows cards the player
# doesn't yet own at their copy limit -- the direct answer to "which card do
# I craft with these Vials I just earned?" without scrolling past cards
# already owned.
var collection_missing_only := false
var battle_select_class := "Hope"
var battle_select_mode := "custom"
var battle_opponent_class := "Courage"
var battle_opponent_mode := "prebuilt"
var pending_after_class_choice: Callable = Callable()
var status_label: Label
var academy_complete := false
var academy_step := 0
var academy_reward_claimed := false
var academy_action_stage := 0
var academy_transition_in_progress := false
var academy_feedback: Label
var academy_feedback_chip: Panel
var access_status: Label
var access_token_input: LineEdit
var daily_reward_day := 0
var daily_last_claim_day := -1
var online_server_input: LineEdit
var online_room_input: LineEdit
var online_status: Label
var online_selected_class := "Hope"
var online_selected_deck_mode := "custom"
var online_hosting := false
var launch_status: Label
var launch_email: LineEdit
var launch_password: LineEdit
var launch_screen_active := false
var home_music: AudioStreamPlayer
var contact_message_input: TextEdit
var contact_status: Label
var last_seen_whats_new_version := ""
var whats_new_checked_this_session := false
# Upload safety gate — set to true only after a successful cloud profile fetch
# and apply. Any path that leaves this false will block all save uploads so an
# empty/default local save can never overwrite real cloud data.
var _cloud_safe_to_upload := false
# Snapshot of the last successfully fetched cloud save, used by the upload
# integrity check to block uploads that would regress collection/progress.
var _last_cloud_snapshot: Dictionary = {}
# First-login onboarding gate.  Set to true once the player has chosen and
# claimed their starter deck.  Saved to both local disk and Supabase so it
# persists across devices and reinstalls.  False only for brand-new accounts
# that have never chosen a class.
var starter_deck_selected := false
const SUPPORT_EMAIL := "walkingfreeagain@gmail.com"

func ensure_home_music() -> void:
    # Home music lives in the AudioManager autoload so screen rebuilds cannot
    # delete the player. clear_screen() removes menu children every time the UI
    # changes, which was silently freeing the old local AudioStreamPlayer.
    AudioManager.play_home_music()

func stop_home_music() -> void:
    AudioManager.stop_music()

func is_mobile_device() -> bool:
    return OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")

func ui_font_size(value: int) -> int:
    return int(round(float(value) * (1.18 if is_mobile_device() else 1.0)))

func safe_set_text(node: Object, value: String) -> void:
    if node != null and is_instance_valid(node) and "text" in node:
        node.set("text", value)

func _ready() -> void:
    randomize()
    ensure_home_music()
    # Fast-path back into the Academy when returning from a tutorial battle —
    # reads the flag that _tutorial_complete() writes, skips the launch screen,
    # and shows the next lesson immediately.
    var _tut_cfg := ConfigFile.new()
    if _tut_cfg.load("user://battle_setup.cfg") == OK \
            and str(_tut_cfg.get_value("battle","mode","")) == "tutorial" \
            and bool(_tut_cfg.get_value("tutorial","lesson_complete",false)):
        _tut_cfg.set_value("tutorial","lesson_complete",false)
        _tut_cfg.save("user://battle_setup.cfg")
        cards = load_cards()
        load_profile()
        # ── Academy lesson-completion fast path ─────────────────────────────
        # BUG FIX: the original code called show_home() unconditionally, which
        # discarded the "lesson just finished" signal and never advanced the
        # Academy step, never saved that progress to Supabase, and never
        # returned the player to the Academy lesson-select screen.
        #
        # Correct behaviour:
        #  • Graduated players (academy_complete = true) replaying a lesson
        #    should NOT re-advance; send them home as before.
        #  • First-time completers must call complete_academy_lesson_once()
        #    which: increments academy_step, calls save_profile() (local +
        #    queued cloud upload), then navigates to show_academy_lesson() or
        #    show_academy_graduation(). That function is already idempotent
        #    (academy_transition_in_progress guard) and fully logged.
        print("ACADEMY RETURN: user=%s step=%d academy_complete=%s" % [
            NetworkManager.user_id, academy_step, str(academy_complete)])
        if academy_complete:
            # Graduated player replaying — go home, not back into the sequence.
            print("ACADEMY RETURN: already complete — returning home")
            show_home()
        else:
            # First-time completion: advance step, save, navigate to academy.
            print("ACADEMY RETURN: advancing step=%d via complete_academy_lesson_once" % academy_step)
            complete_academy_lesson_once(academy_step)
        return
    # Fast-path back to Home after a normal battle — skip login since the
    # player is already authenticated. Flag written by _return_to_main_menu()
    # and the HOME button in the battle scene.
    var _nav_cfg := ConfigFile.new()
    if _nav_cfg.load("user://nav.cfg") == OK \
            and bool(_nav_cfg.get_value("nav", "return_from_battle", false)):
        _nav_cfg.set_value("nav", "return_from_battle", false)
        _nav_cfg.save("user://nav.cfg")
        cards = load_cards()
        load_profile()
        show_home()
        return
    if not get_viewport().size_changed.is_connected(_on_viewport_size_changed):
        get_viewport().size_changed.connect(_on_viewport_size_changed)
    if not AccessManager.authentication_finished.is_connected(_on_access_authentication_finished):
        AccessManager.authentication_finished.connect(_on_access_authentication_finished)
    if not BillingManager.purchase_completed.is_connected(_on_billing_purchase_completed):
        BillingManager.purchase_completed.connect(_on_billing_purchase_completed)
    if not BillingManager.purchase_failed.is_connected(_on_billing_purchase_failed):
        BillingManager.purchase_failed.connect(_on_billing_purchase_failed)
    if not BillingManager.products_updated.is_connected(_on_billing_products_updated):
        BillingManager.products_updated.connect(_on_billing_products_updated)
    if not NetworkManager.connected_to_service.is_connected(_on_online_connected):
        NetworkManager.connected_to_service.connect(_on_online_connected)
    if not NetworkManager.room_created.is_connected(_on_online_room_created):
        NetworkManager.room_created.connect(_on_online_room_created)
    if not NetworkManager.room_joined.is_connected(_on_online_room_joined):
        NetworkManager.room_joined.connect(_on_online_room_joined)
    if not NetworkManager.lobby_updated.is_connected(_on_online_lobby_updated):
        NetworkManager.lobby_updated.connect(_on_online_lobby_updated)
    if not NetworkManager.match_started.is_connected(_on_online_match_started):
        NetworkManager.match_started.connect(_on_online_match_started)
    if not NetworkManager.network_error.is_connected(_on_online_error):
        NetworkManager.network_error.connect(_on_online_error)
    if not NetworkManager.account_authenticated.is_connected(_on_launch_auth_result):
        NetworkManager.account_authenticated.connect(_on_launch_auth_result)
    if not NetworkManager.cloud_save_loaded.is_connected(_on_cloud_save_loaded):
        NetworkManager.cloud_save_loaded.connect(_on_cloud_save_loaded)
    cards = load_cards()
    load_profile()
    show_launch_screen()
    if NetworkManager.connected and not NetworkManager.access_token.is_empty():
        launch_status.text = "Restoring account session..."
        NetworkManager.validate_saved_session()

func show_launch_screen() -> void:
    ensure_home_music()
    launch_screen_active = true
    clear_screen()
    add_background(0.96)

    # ── Left half: 2×2 leader portrait mosaic ─────────────────────────────────
    var leaders_data := [
        {"name": "Hope",     "color": Color(0.25, 0.55, 1.00)},
        {"name": "Courage",  "color": Color(0.95, 0.40, 0.18)},
        {"name": "Serenity", "color": Color(0.28, 0.75, 0.55)},
        {"name": "Purpose",  "color": Color(0.72, 0.38, 0.90)},
    ]
    var grid_w := 310.0; var grid_h := 360.0
    var grid_origins := [Vector2(0,0), Vector2(grid_w,0), Vector2(0,grid_h), Vector2(grid_w,grid_h)]
    for i in range(4):
        var ld: Dictionary = leaders_data[i]
        var lname: String = str(ld.get("name",""))
        var lcol: Color  = ld.get("color", GOLD_COLOR)

        var frame := Panel.new()
        frame.position = grid_origins[i]
        frame.size = Vector2(grid_w, grid_h)
        frame.clip_contents = true
        frame.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
        root_layer.add_child(frame)

        var portrait := TextureRect.new()
        portrait.texture = current_leader_texture(lname)
        portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
        portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
        frame.add_child(portrait)

        # Bottom scrim so class name is readable
        var scrim := ColorRect.new()
        scrim.color = Color(0.01, 0.02, 0.04, 0.72)
        scrim.position = Vector2(0, grid_h * 0.62)
        scrim.size = Vector2(grid_w, grid_h * 0.38)
        scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
        frame.add_child(scrim)

        var name_lbl := centered_label(lname.to_upper(), Vector2(0, grid_h - 40), Vector2(grid_w, 32), 17, frame)
        name_lbl.add_theme_color_override("font_color", lcol)

        # Class-coloured accent bar along the top
        var top_bar := ColorRect.new(); top_bar.color = lcol
        top_bar.position = Vector2.ZERO; top_bar.size = Vector2(grid_w, 4)
        top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE; frame.add_child(top_bar)

        # Thin border on inner edges (right edge for left column, bottom edge for top row)
        var inner_v := ColorRect.new(); inner_v.color = Color(lcol, 0.6)
        inner_v.position = Vector2(grid_w - 2, 0); inner_v.size = Vector2(2, grid_h)
        inner_v.mouse_filter = Control.MOUSE_FILTER_IGNORE; frame.add_child(inner_v)
        var inner_h := ColorRect.new(); inner_h.color = Color(lcol, 0.6)
        inner_h.position = Vector2(0, grid_h - 2); inner_h.size = Vector2(grid_w, 2)
        inner_h.mouse_filter = Control.MOUSE_FILTER_IGNORE; frame.add_child(inner_h)

    # Vertical gold divider between mosaic and login panel
    var divider := ColorRect.new()
    divider.position = Vector2(620, 0); divider.size = Vector2(3, 720)
    divider.color = GOLD_COLOR; divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root_layer.add_child(divider)

    # ── Right half: login form ─────────────────────────────────────────────────
    var right := Panel.new()
    right.position = Vector2(623, 0); right.size = Vector2(657, 720)
    var rg_style := StyleBoxFlat.new()
    rg_style.bg_color = Color(0.022, 0.032, 0.060, 0.99)
    right.add_theme_stylebox_override("panel", rg_style)
    root_layer.add_child(right)

    # Game branding
    var title_lbl := centered_label("WALKING FREE CCG", Vector2(20, 70), Vector2(617, 54), 34, right)
    title_lbl.add_theme_color_override("font_color", GOLD_COLOR)
    var sub_lbl := centered_label("JOURNEY'S DAWN", Vector2(20, 126), Vector2(617, 32), 20, right)
    sub_lbl.add_theme_color_override("font_color", Color(0.76, 0.83, 0.96))

    # Gold separator
    var hsep := ColorRect.new(); hsep.position = Vector2(80, 170); hsep.size = Vector2(497, 2)
    hsep.color = Color(GOLD_COLOR, 0.45); hsep.mouse_filter = Control.MOUSE_FILTER_IGNORE
    right.add_child(hsep)

    centered_label("Sign in to save your collection and progress.", Vector2(60, 182), Vector2(537, 26), 13, right).modulate = Color(0.62, 0.70, 0.85)

    # Input field shared style
    var field_norm := StyleBoxFlat.new()
    field_norm.bg_color = Color(0.055, 0.08, 0.15)
    field_norm.border_color = Color(0.30, 0.40, 0.62)
    field_norm.set_border_width_all(2); field_norm.set_corner_radius_all(10)
    field_norm.content_margin_left = 16; field_norm.content_margin_right = 10

    var field_focus := StyleBoxFlat.new()
    field_focus.bg_color = Color(0.06, 0.09, 0.18)
    field_focus.border_color = GOLD_COLOR
    field_focus.set_border_width_all(2); field_focus.set_corner_radius_all(10)
    field_focus.content_margin_left = 16; field_focus.content_margin_right = 10

    # Email
    label("EMAIL", Vector2(80, 228), Vector2(200, 20), 11, right).add_theme_color_override("font_color", Color(0.58, 0.68, 0.86))
    launch_email = LineEdit.new()
    launch_email.position = Vector2(80, 250); launch_email.size = Vector2(497, 52)
    launch_email.placeholder_text = "your@email.com"
    launch_email.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
    launch_email.add_theme_font_size_override("font_size", 18)
    launch_email.add_theme_stylebox_override("normal", field_norm)
    launch_email.add_theme_stylebox_override("focus",  field_focus)
    right.add_child(launch_email)

    # Password
    label("PASSWORD", Vector2(80, 316), Vector2(200, 20), 11, right).add_theme_color_override("font_color", Color(0.58, 0.68, 0.86))
    launch_password = LineEdit.new()
    launch_password.position = Vector2(80, 338); launch_password.size = Vector2(497, 52)
    launch_password.placeholder_text = "••••••••"
    launch_password.secret = true
    launch_password.add_theme_font_size_override("font_size", 18)
    launch_password.add_theme_stylebox_override("normal", field_norm)
    launch_password.add_theme_stylebox_override("focus",  field_focus)
    right.add_child(launch_password)

    # Primary SIGN IN
    var si_style := solid_style(GOLD_COLOR, 12)
    var si_hover  := solid_style(GOLD_COLOR.lightened(0.18), 12)
    var sign_in := button("SIGN IN", Vector2(80, 414), Vector2(497, 58), func():
        _cloud_safe_to_upload = false
        launch_status.text = "Signing in..."
        launch_status.add_theme_color_override("font_color", Color(0.94, 0.95, 1.0))
        NetworkManager.sign_in_with_email(launch_email.text, launch_password.text)
    , right)
    sign_in.add_theme_font_size_override("font_size", ui_font_size(21))
    sign_in.add_theme_stylebox_override("normal",  si_style)
    sign_in.add_theme_stylebox_override("hover",   si_hover)
    sign_in.add_theme_stylebox_override("pressed", si_style)
    sign_in.add_theme_color_override("font_color",       Color(0.06, 0.04, 0.01))
    sign_in.add_theme_color_override("font_hover_color", Color(0.06, 0.04, 0.01))

    # Secondary row
    button("CREATE ACCOUNT", Vector2(80, 486), Vector2(238, 50), func():
        launch_status.text = "Creating account..."
        launch_status.add_theme_color_override("font_color", Color(0.94, 0.95, 1.0))
        NetworkManager.create_account_with_email(launch_email.text, launch_password.text)
    , right)
    button("CONTINUE AS GUEST", Vector2(339, 486), Vector2(238, 50), func():
        launch_status.text = "Starting guest session..."
        NetworkManager.continue_as_guest()
    , right)

    launch_status = centered_label("", Vector2(60, 552), Vector2(537, 28), 14, right)

    # Bottom quote + build label
    var quote := centered_label("\"One day at a time.\"", Vector2(60, 630), Vector2(537, 32), 19, right)
    quote.add_theme_color_override("font_color", Color(GOLD_COLOR, 0.52))
    centered_label(BUILD_NAME, Vector2(60, 672), Vector2(537, 22), 11, right).modulate = Color(0.38, 0.46, 0.60)

func _on_launch_auth_result(success: bool, message: String) -> void:
    print("LOGIN RESULT ── success=%s  message='%s'  user_id=%s  role=%s  cloud_safe=%s" % [
        str(success), message, NetworkManager.user_id, NetworkManager.account_role, str(_cloud_safe_to_upload)])
    if is_instance_valid(launch_status):
        launch_status.text = message
        launch_status.add_theme_color_override("font_color", Color(0.55, 1.0, 0.70) if success else Color(1.0, 0.55, 0.55))
    if not success:
        print("LOGIN RESULT ── FAILED — staying on launch screen, upload gate remains locked")
        return
    if NetworkManager.account_role == "owner":
        message += " Developer access enabled."
    elif NetworkManager.account_role == "tester":
        message += " Tester account ready."
    if is_instance_valid(launch_status):
        launch_status.text = message
    print("LOGIN RESULT ── SUCCESS — gold=%d vials=%d packs=%d cards=%d  cloud_safe=%s" % [
        gold_balance, dust_balance, pack_inventory, collection_owned.size(), str(_cloud_safe_to_upload)])
    launch_screen_active = false
    await get_tree().create_timer(0.35).timeout
    print("LOGIN RESULT ── HOME SCREEN OPENED")
    if can_claim_daily_reward():
        auto_claim_daily_reward_after_login()
    else:
        show_home()

func _on_viewport_size_changed() -> void:
    # On Android the virtual keyboard fires this signal. Previously this called
    # show_launch_screen() which wiped whatever the player had typed into the
    # email/password fields. The launch panel is fixed-position and does not
    # depend on viewport dimensions, so skip the rebuild entirely.
    if launch_screen_active:
        return
    show_home()

func load_cards() -> Array:
    var file := FileAccess.open("res://data/cards.json", FileAccess.READ)
    if file == null:
        return []
    var parsed = JSON.parse_string(file.get_as_text())
    return parsed if parsed is Array else []

func load_profile() -> void:
    var cfg := ConfigFile.new()
    if cfg.load(SAVE_PATH) == OK:
        gold_balance = int(cfg.get_value("economy", "gold", 0))
        dust_balance = int(cfg.get_value("economy", "dust", 0))
        pack_inventory = int(cfg.get_value("economy", "packs", 0))
        packs_opened = int(cfg.get_value("packs", "opened", 0))
        platinum_pity = int(cfg.get_value("packs", "platinum_pity", 0))
        legendary_pity = int(cfg.get_value("packs", "legendary_pity", 0))
        selected_class = str(cfg.get_value("profile", "class", ""))
        collection_owned = cfg.get_value("collection", "owned", {})
        collection_shiny_owned = cfg.get_value("collection", "shiny_owned", {})
        selected_deck_class = str(cfg.get_value("deck", "class", "Hope"))
        saved_decks = cfg.get_value("decks", "by_class", {})
        if saved_decks.is_empty():
            # Migrate the older single-deck save into its original class slot.
            saved_deck = cfg.get_value("deck", "cards", [])
            if not saved_deck.is_empty():
                saved_decks[selected_deck_class] = saved_deck.duplicate()
        saved_deck = Array(saved_decks.get(selected_deck_class, []))
        academy_complete = bool(cfg.get_value("academy", "complete", false))
        academy_step = clampi(int(cfg.get_value("academy", "step", 0)), 0, ACADEMY_LESSON_COUNT)
        academy_reward_claimed = bool(cfg.get_value("academy", "reward_claimed", false))
        daily_reward_day = int(cfg.get_value("daily", "reward_day", 0))
        daily_last_claim_day = int(cfg.get_value("daily", "last_claim_day", -1))
        recovery_challenge_progress = cfg.get_value("challenge", "recovery_progress", {})
        challenge_week_key = str(cfg.get_value("challenge", "week_key", ""))
        # Reset progress if we've rolled into a new week.  This is what makes
        # the home screen label say "this week's challenge" with actual meaning.
        var current_week := _current_week_key()
        if challenge_week_key != current_week:
            recovery_challenge_progress = {}
            challenge_week_key = current_week
        trials_cleared = cfg.get_value("trials", "cleared", {})
        sponsor_leader_unlocked = bool(cfg.get_value("trials", "sponsor_leader_unlocked", false))
        sponsor_sleeve_unlocked = bool(cfg.get_value("trials", "sponsor_sleeve_unlocked", false))
        sponsor_defeated = bool(cfg.get_value("trials", "sponsor_defeated", false))
        owned_sleeves = Array(cfg.get_value("cosmetics", "owned_sleeves", []))
        equipped_sleeve = str(cfg.get_value("cosmetics", "equipped_sleeve", ""))
        selected_leader_skin = str(cfg.get_value("trials", "selected_leader_skin", ""))
        last_seen_whats_new_version = str(cfg.get_value("meta", "last_seen_whats_new_version", ""))
        deck_slots = cfg.get_value("deck_slots", "slots", [])
        last_trial_deck_idx = int(cfg.get_value("deck_slots", "last_trial_idx", -1))
        last_battle_deck_idx = int(cfg.get_value("deck_slots", "last_battle_idx", -1))
        if deck_slots.is_empty():
            _migrate_saved_decks_to_slots()
        starter_deck_selected = bool(cfg.get_value("onboarding", "starter_deck_selected", false))
        # Migration: any player who already has cards or deck slots is treated as
        # having completed the starter-deck step even if the flag was never written.
        # This ensures no existing player is ever shown the onboarding screen.
        if not starter_deck_selected and (collection_owned.size() > 0 or deck_slots.size() > 0):
            starter_deck_selected = true
        # Existing players from earlier builds should not lose access.
        if selected_class != "" and not cfg.has_section_key("academy", "complete"):
            academy_complete = true
            academy_reward_claimed = true
        migrate_sponsor_out_of_prebuilt_deck()
    print("LOAD_PROFILE ── DISK READ : gold=%d  vials=%d  packs=%d  cards=%d" % [
        gold_balance, dust_balance, pack_inventory, collection_owned.size()])

func migrate_sponsor_out_of_prebuilt_deck() -> void:
    # v0.6.3 migration: Sponsor used to be inserted into every starter deck.
    # Remove that automatic copy while preserving the rest of the player's deck.
    var removed := false
    while saved_deck.has("JD-080"):
        saved_deck.erase("JD-080")
        removed = true
    if not removed:
        return
    # Fill the open slot with an owned, legal class/Neutral card so the deck
    # remains at 40. Sponsor stays in the collection and may be added manually.
    while saved_deck.size() < 40:
        var added := false
        for card_data in cards:
            var id := str(card_data.get("id", ""))
            var card_class := str(card_data.get("class", ""))
            if id == "JD-080":
                continue
            if card_class != selected_deck_class and card_class != "Neutral":
                continue
            var rarity := str(card_data.get("rarity", "Bronze"))
            var limit := int(COPY_LIMITS.get(rarity, int(card_data.get("max_copies", 1))))
            var owned := int(collection_owned.get(id, 0))
            if count_in_deck(id) < mini(limit, owned):
                saved_deck.append(id)
                added = true
                break
        if not added:
            break

func _current_week_key() -> String:
    # Returns a monotonically-increasing week bucket string.
    # 604800 = seconds in one week.  Changes every Monday at ~00:00 UTC.
    return str(int(Time.get_unix_time_from_system() / 604800.0))

func save_profile() -> void:
    var cfg := ConfigFile.new()
    cfg.set_value("economy", "gold", gold_balance)
    cfg.set_value("economy", "dust", dust_balance)
    cfg.set_value("economy", "packs", pack_inventory)
    cfg.set_value("packs", "opened", packs_opened)
    cfg.set_value("packs", "platinum_pity", platinum_pity)
    cfg.set_value("packs", "legendary_pity", legendary_pity)
    cfg.set_value("profile", "class", selected_class)
    cfg.set_value("collection", "owned", collection_owned)
    cfg.set_value("collection", "shiny_owned", collection_shiny_owned)
    saved_decks[selected_deck_class] = saved_deck.duplicate()
    cfg.set_value("deck", "cards", saved_deck) # Backward-compatible active deck.
    cfg.set_value("deck", "class", selected_deck_class)
    cfg.set_value("decks", "by_class", saved_decks)
    cfg.set_value("academy", "complete", academy_complete)
    cfg.set_value("academy", "step", academy_step)
    cfg.set_value("academy", "reward_claimed", academy_reward_claimed)
    cfg.set_value("daily", "reward_day", daily_reward_day)
    cfg.set_value("daily", "last_claim_day", daily_last_claim_day)
    cfg.set_value("challenge", "recovery_progress", recovery_challenge_progress)
    cfg.set_value("challenge", "week_key", challenge_week_key)
    cfg.set_value("trials", "cleared", trials_cleared)
    cfg.set_value("trials", "sponsor_leader_unlocked", sponsor_leader_unlocked)
    cfg.set_value("trials", "sponsor_sleeve_unlocked", sponsor_sleeve_unlocked)
    cfg.set_value("trials", "sponsor_defeated", sponsor_defeated)
    cfg.set_value("cosmetics", "owned_sleeves", owned_sleeves)
    cfg.set_value("cosmetics", "equipped_sleeve", equipped_sleeve)
    cfg.set_value("trials", "selected_leader_skin", selected_leader_skin)
    cfg.set_value("meta", "last_seen_whats_new_version", last_seen_whats_new_version)
    cfg.set_value("onboarding", "starter_deck_selected", starter_deck_selected)
    # Multi-deck slots — sync the currently-editing slot before writing.
    if editing_deck_slot_idx >= 0 and editing_deck_slot_idx < deck_slots.size():
        deck_slots[editing_deck_slot_idx]["cards"] = saved_deck.duplicate()
        deck_slots[editing_deck_slot_idx]["class"] = selected_deck_class
    cfg.set_value("deck_slots", "slots", deck_slots)
    cfg.set_value("deck_slots", "last_trial_idx", last_trial_deck_idx)
    cfg.set_value("deck_slots", "last_battle_idx", last_battle_deck_idx)
    cfg.save(SAVE_PATH)
    # Fire-and-forget cloud backup. Runs after this frame so the local save
    # always lands first; silently skipped when not signed in.
    _queue_cloud_upload.call_deferred()

# ── Cloud save helpers ────────────────────────────────────────────────────────

func _queue_cloud_upload() -> void:
    if NetworkManager.user_id.is_empty():
        push_warning("CLOUD UPLOAD ── BLOCKED: not authenticated")
        return
    if not _cloud_safe_to_upload:
        push_error("CLOUD UPLOAD ── BLOCKED: cloud profile was not safely fetched and applied — refusing to overwrite cloud data with local state")
        return
    var outgoing := _serialize_profile_for_cloud()
    var _out_packs: int = int(((outgoing.get("economy", {}) as Dictionary).get("packs", -1)))
    print("CLOUD UPLOAD ── OUTGOING PACKS = %d  (in-memory pack_inventory=%d)" % [_out_packs, pack_inventory])
    if not _upload_integrity_ok(outgoing):
        push_error("CLOUD UPLOAD ── BLOCKED: integrity check failed — outgoing save would regress cloud progress")
        return
    print("CLOUD UPLOAD ── ALLOWED  user_id=%s  gold=%d vials=%d packs=%d cards=%d" % [
        NetworkManager.user_id, gold_balance, dust_balance, pack_inventory, collection_owned.size()])
    await NetworkManager.upload_save_data(outgoing)

## Compare the outgoing save against the last known cloud snapshot.
## Returns false (and logs the reason) if the upload would regress any
## critical progress field. Always returns true when there is no prior snapshot.
func _upload_integrity_ok(outgoing: Dictionary) -> bool:
    if _last_cloud_snapshot.is_empty():
        print("CLOUD INTEGRITY ── no prior snapshot, first sync allowed")
        return true

    # ── Collection must never shrink ──────────────────────────────────────────
    var snap_coll: Variant = _last_cloud_snapshot.get("collection", {})
    var out_coll: Variant  = outgoing.get("collection", {})
    if snap_coll is Dictionary and out_coll is Dictionary:
        var snap_owned: Variant = (snap_coll as Dictionary).get("owned", {})
        var out_owned: Variant  = (out_coll  as Dictionary).get("owned", {})
        var snap_n := (snap_owned as Dictionary).size() if snap_owned is Dictionary else 0
        var out_n  := (out_owned  as Dictionary).size() if out_owned  is Dictionary else 0
        if out_n < snap_n:
            push_error("CLOUD INTEGRITY ── FAIL: collection would shrink %d -> %d cards" % [snap_n, out_n])
            return false

    # ── Economy must not crater (allow normal spending, block total wipe) ──────
    var snap_econ: Variant = _last_cloud_snapshot.get("economy", {})
    var out_econ: Variant  = outgoing.get("economy", {})
    if snap_econ is Dictionary and out_econ is Dictionary:
        var snap_gold := int((snap_econ as Dictionary).get("gold", 0))
        var out_gold  := int((out_econ  as Dictionary).get("gold", 0))
        # Block upload if gold would drop by more than 90% AND cloud had >500 gold.
        # Legitimate spending never wipes a whole balance in one save cycle.
        if snap_gold > 500 and out_gold < int(snap_gold * 0.10):
            push_error("CLOUD INTEGRITY ── FAIL: gold would drop %d -> %d (>90%% loss)" % [snap_gold, out_gold])
            return false

    # ── Academy must not regress ───────────────────────────────────────────────
    var snap_acad: Variant = _last_cloud_snapshot.get("academy", {})
    var out_acad: Variant  = outgoing.get("academy", {})
    if snap_acad is Dictionary and out_acad is Dictionary:
        var snap_complete := _safe_bool((snap_acad as Dictionary).get("complete", false))
        var out_complete  := _safe_bool((out_acad  as Dictionary).get("complete", false))
        var snap_step     := int((snap_acad as Dictionary).get("step", 0))
        var out_step      := int((out_acad  as Dictionary).get("step", 0))
        if snap_complete and not out_complete:
            push_error("CLOUD INTEGRITY ── FAIL: academy.complete would regress true -> false")
            return false
        if out_step < snap_step:
            push_error("CLOUD INTEGRITY ── FAIL: academy.step would regress %d -> %d" % [snap_step, out_step])
            return false

    # ── Trials must not shrink ────────────────────────────────────────────────
    var snap_trials: Variant = _last_cloud_snapshot.get("trials", {})
    var out_trials: Variant  = outgoing.get("trials", {})
    if snap_trials is Dictionary and out_trials is Dictionary:
        var snap_cleared: Variant = (snap_trials as Dictionary).get("cleared", {})
        var out_cleared: Variant  = (out_trials  as Dictionary).get("cleared", {})
        var snap_n2 := (snap_cleared as Dictionary).size() if snap_cleared is Dictionary else 0
        var out_n2  := (out_cleared  as Dictionary).size() if out_cleared  is Dictionary else 0
        if out_n2 < snap_n2:
            push_error("CLOUD INTEGRITY ── FAIL: trials.cleared would shrink %d -> %d" % [snap_n2, out_n2])
            return false

    print("CLOUD INTEGRITY ── OK")
    return true

func _serialize_profile_for_cloud() -> Dictionary:
    saved_decks[selected_deck_class] = saved_deck.duplicate()
    if editing_deck_slot_idx >= 0 and editing_deck_slot_idx < deck_slots.size():
        deck_slots[editing_deck_slot_idx]["cards"] = saved_deck.duplicate()
        deck_slots[editing_deck_slot_idx]["class"] = selected_deck_class
    return {
        "economy": {"gold": gold_balance, "dust": dust_balance, "packs": pack_inventory},
        "packs": {"opened": packs_opened, "platinum_pity": platinum_pity, "legendary_pity": legendary_pity},
        "profile": {"class": selected_class},
        "collection": {"owned": collection_owned, "shiny_owned": collection_shiny_owned},
        "deck": {"class": selected_deck_class, "cards": saved_deck},
        "decks": {"by_class": saved_decks},
        "deck_slots": {
            "slots": deck_slots,
            "last_trial_idx": last_trial_deck_idx,
            "last_battle_idx": last_battle_deck_idx
        },
        "academy": {"complete": academy_complete, "step": academy_step, "reward_claimed": academy_reward_claimed},
        "daily": {"reward_day": daily_reward_day, "last_claim_day": daily_last_claim_day},
        "challenge": {"recovery_progress": recovery_challenge_progress, "week_key": challenge_week_key},
        "trials": {
            "cleared": trials_cleared,
            "sponsor_leader_unlocked": sponsor_leader_unlocked,
            "sponsor_sleeve_unlocked": sponsor_sleeve_unlocked,
            "sponsor_defeated": sponsor_defeated,
            "selected_leader_skin": selected_leader_skin
        },
        "meta": {"last_seen_whats_new_version": last_seen_whats_new_version},
        "onboarding": {"starter_deck_selected": starter_deck_selected}
    }

## Safely coerce any Variant to bool without crashing on null.
## ConfigFile.get_value() returns null when the key is missing; GDScript's
## bool() constructor cannot accept null and throws "Invalid call. Nonexistent
## 'bool' constructor." Use this helper wherever a ConfigFile value may be null.
func _safe_bool(v: Variant) -> bool:
    if v == null:
        return false
    if v is bool:
        return v
    if v is int or v is float:
        return v != 0
    return false

## Merge cloud save Dictionary into the local ConfigFile.
## Returns true on success, false if anything goes wrong.
## The caller MUST NOT upload to Supabase when this returns false.
func _apply_cloud_profile(data: Dictionary) -> bool:
    # Merge cloud save Dictionary into the local ConfigFile.
    # Rules: progress never regresses; collection never shrinks; decks only
    # replaced by cloud when cloud is non-empty; pending_rewards applied once.
    if data.is_empty():
        return true

    var cfg := ConfigFile.new()
    cfg.load(SAVE_PATH)

    for section in data.keys():
        if section == "pending_rewards":
            continue  # Handled separately below
        var sec_data: Variant = data[section]
        if not (sec_data is Dictionary):
            push_warning("CLOUD MERGE: section '%s' is not a Dictionary (type=%d) — skipping" % [section, typeof(sec_data)])
            continue
        for key in sec_data.keys():
            var cloud_val: Variant = sec_data[key]
            var local_val: Variant = cfg.get_value(section, key, null)

            # ── Boolean progress flags: OR — never regress ─────────────────────
            if (section == "academy" and key in ["complete", "reward_claimed"]) or \
               (section == "trials" and key in ["sponsor_leader_unlocked",
                    "sponsor_sleeve_unlocked", "sponsor_defeated"]) or \
               (section == "onboarding" and key == "starter_deck_selected"):
                cfg.set_value(section, key, _safe_bool(local_val) or _safe_bool(cloud_val))
                continue

            # ── Numeric progress counters: max — never regress ─────────────────
            if (section == "academy" and key == "step") or \
               (section == "economy" and key in ["gold", "dust", "packs"]) or \
               (section == "packs" and key in ["platinum_pity", "legendary_pity", "opened"]):
                cfg.set_value(section, key, maxi(int(local_val if local_val != null else 0), int(cloud_val)))
                continue

            # ── challenge.week_key: cloud wins (take the more recent week) ────────
            if section == "challenge" and key == "week_key":
                var local_wk := str(local_val if local_val != null else "")
                var cloud_wk := str(cloud_val if cloud_val != null else "")
                # Both are stringified unix-week integers; higher number = later week.
                var merged_wk := cloud_wk if int(cloud_wk) >= int(local_wk) else local_wk
                cfg.set_value(section, key, merged_wk)
                # If cloud says a later week, reset local progress too.
                if merged_wk != local_wk:
                    cfg.set_value("challenge", "recovery_progress", {})
                continue

            # ── challenge.recovery_progress: {class: int}, max per key ────────
            if section == "challenge" and key == "recovery_progress":
                var ld: Dictionary = local_val if local_val is Dictionary else {}
                var cd: Dictionary = cloud_val if cloud_val is Dictionary else {}
                var md := ld.duplicate()
                for cls in cd.keys():
                    md[cls] = maxi(int(md.get(cls, 0)), int(cd[cls]))
                cfg.set_value(section, key, md)
                continue

            # ── collection.owned: {card_id: count}, max per key ───────────────
            # NEVER reduce a card count — union with cloud by taking the higher value.
            if section == "collection" and key == "owned":
                var ld: Dictionary = local_val if local_val is Dictionary else {}
                var cd: Dictionary = cloud_val if cloud_val is Dictionary else {}
                var md := ld.duplicate()
                for card_id in cd.keys():
                    md[card_id] = maxi(int(md.get(card_id, 0)), int(cd[card_id]))
                cfg.set_value(section, key, md)
                print("APPLY collection.owned  : local=%d  cloud=%d  merged=%d" % [
                    ld.size(), cd.size(), md.size()])
                continue

            # ── trials.cleared: {trial_key: bool}, union ──────────────────────
            # Never un-clear a trial that either side considers cleared.
            if section == "trials" and key == "cleared":
                var ld: Dictionary = local_val if local_val is Dictionary else {}
                var cd: Dictionary = cloud_val if cloud_val is Dictionary else {}
                var md := ld.duplicate()
                for trial_key in cd.keys():
                    if _safe_bool(cd[trial_key]):
                        md[trial_key] = true
                cfg.set_value(section, key, md)
                print("APPLY trials.cleared    : local=%d  cloud=%d  merged=%d" % [
                    ld.size(), cd.size(), md.size()])
                continue

            # ── deck_slots.slots: cloud wins wholesale ─────────────────────────
            if section == "deck_slots" and key == "slots":
                if cloud_val is Array:
                    cfg.set_value(section, key, cloud_val)
                continue

            # ── deck.cards / decks.by_class: cloud wins ONLY if non-empty ─────
            # An empty cloud deck must NOT erase a valid local deck.  This covers
            # the partial-overwrite failure mode where a default local save was
            # previously uploaded, setting deck.cards=[] in Supabase.
            if section == "deck" and key == "cards":
                var cloud_nonempty := cloud_val is Array and not (cloud_val as Array).is_empty()
                if cloud_nonempty:
                    cfg.set_value(section, key, cloud_val)
                print("APPLY deck.cards        : cloud_cards=%d  %s" % [
                    (cloud_val as Array).size() if cloud_val is Array else 0,
                    "APPLIED" if cloud_nonempty else "KEPT LOCAL (cloud empty)"])
                continue

            if section == "decks" and key == "by_class":
                if cloud_val is Dictionary:
                    var cloud_has_any := false
                    for cls_key in (cloud_val as Dictionary).keys():
                        var v: Variant = (cloud_val as Dictionary)[cls_key]
                        if v is Array and not (v as Array).is_empty():
                            cloud_has_any = true
                            break
                    if cloud_has_any:
                        cfg.set_value(section, key, cloud_val)
                    print("APPLY decks.by_class    : cloud_has_content=%s  %s" % [
                        str(cloud_has_any), "APPLIED" if cloud_has_any else "KEPT LOCAL (cloud empty)"])
                continue

            # ── Other Array fields: union ──────────────────────────────────────
            if cloud_val is Array:
                var merged: Array = (local_val.duplicate() if local_val is Array else [])
                for entry in cloud_val:
                    if not merged.has(entry):
                        merged.append(entry)
                cfg.set_value(section, key, merged)
                continue

            # ── All other fields: cloud wins ───────────────────────────────────
            cfg.set_value(section, key, cloud_val)

    # ── Apply pending_rewards if present in cloud save ────────────────────────
    # pending_rewards = {gold: int, vials: int, packs: int}
    # Applied once here then must be cleared from Supabase by the caller.
    if data.has("pending_rewards"):
        var pr: Variant = data["pending_rewards"]
        if pr is Dictionary:
            var pg := int(pr.get("gold", 0))
            var pv := int(pr.get("vials", 0))
            var pp := int(pr.get("packs", 0))
            if pg > 0 or pv > 0 or pp > 0:
                print("APPLY pending_rewards   : +gold=%d  +vials=%d  +packs=%d" % [pg, pv, pp])
                cfg.set_value("economy", "gold",  int(cfg.get_value("economy", "gold",  0)) + pg)
                cfg.set_value("economy", "dust",  int(cfg.get_value("economy", "dust",  0)) + pv)
                cfg.set_value("economy", "packs", int(cfg.get_value("economy", "packs", 0)) + pp)

    var save_err := cfg.save(SAVE_PATH)
    if save_err != OK:
        push_error("CLOUD MERGE: cfg.save() failed (error %d) — upload aborted" % save_err)
        return false

    # ── Per-section summary ────────────────────────────────────────────────────
    var aft := ConfigFile.new(); aft.load(SAVE_PATH)
    print("APPLY economy          : gold=%d  vials=%d  packs=%d" % [
        int(aft.get_value("economy", "gold", 0)),
        int(aft.get_value("economy", "dust", 0)),
        int(aft.get_value("economy", "packs", 0))])
    print("APPLY academy          : complete=%s  step=%d  reward_claimed=%s" % [
        str(_safe_bool(aft.get_value("academy", "complete", false))),
        int(aft.get_value("academy", "step", 0)),
        str(_safe_bool(aft.get_value("academy", "reward_claimed", false)))])
    print("APPLY decks            : deck.cards=%d" % (aft.get_value("deck", "cards", []) as Array).size())
    print("CLOUD MERGE            : SUCCESS")
    return true


func _on_cloud_save_loaded(data: Dictionary, fetch_ok: bool) -> void:
    # ── Snapshot local state before any merge ─────────────────────────────────
    print("CLOUD SYNC ── LOCAL BEFORE MERGE : gold=%d vials=%d packs=%d cards=%d trials=%d challenge=%d academy=%s" % [
        gold_balance, dust_balance, pack_inventory, collection_owned.size(),
        trials_cleared.size(), recovery_challenge_progress.size(), str(academy_complete)])
    var _db_packs: int = ((data.get("economy", {}) as Dictionary).get("packs", -1)) if data is Dictionary else -1
    print("CLOUD SYNC ── FETCH RESULT       : fetch_ok=%s  sections=%d  db_packs=%d  recovery_vials=%d  pending_packs=%d" % [
        str(fetch_ok), data.size(), _db_packs, NetworkManager.fetched_recovery_vials, NetworkManager.fetched_pending_packs])

    # ── Guard: never upload when the network fetch itself failed ──────────────
    if not fetch_ok:
        _cloud_safe_to_upload = false
        push_error("CLOUD SYNC ── FETCH FAILED — upload gate locked. Cloud data is unknown; local save will NOT be uploaded.")
        if is_instance_valid(launch_status):
            launch_status.text = "Cloud save could not be loaded. Progress preserved — try restarting."
            launch_status.add_theme_color_override("font_color", Color(1.0, 0.65, 0.35))
        return

    if data.is_empty():
        # Fetch succeeded but no save_data exists yet (new account or genuinely
        # null). Only upload local data if there is real progress worth keeping.
        var local_has_progress := (gold_balance > 0 or dust_balance > 0
            or pack_inventory > 1 or collection_owned.size() > 0
            or academy_complete or trials_cleared.size() > 0)
        if not NetworkManager.user_id.is_empty() and local_has_progress:
            print("CLOUD SYNC ── ACTION : first sync — local has progress, uploading to Supabase")
            _cloud_safe_to_upload = true
            _queue_cloud_upload.call_deferred()
        elif not NetworkManager.user_id.is_empty():
            print("CLOUD SYNC ── ACTION : local save is empty — NOT uploading (protects any future cloud data)")
        else:
            print("CLOUD SYNC ── ACTION : guest session — skipping upload")
        # Apply any admin-granted column rewards even on a fresh/empty save.
        # If rewards were granted, we know the server state is empty — safe to upload.
        var had_grants := NetworkManager.fetched_recovery_vials > 0 or NetworkManager.fetched_pending_packs > 0
        if had_grants and not NetworkManager.user_id.is_empty():
            _cloud_safe_to_upload = true
            print("CLOUD SYNC ── UPLOAD GATE unlocked by pending column rewards on empty save")
        _apply_pending_column_rewards()
        return

    # ── Remote save found — store snapshot for integrity checks, then merge ─────
    _last_cloud_snapshot = data.duplicate(true)
    print("CLOUD SYNC ── ACTION : applying cloud save (%d sections, local wins on progress)" % data.size())
    var merge_ok := _apply_cloud_profile(data)
    if not merge_ok:
        _cloud_safe_to_upload = false
        push_error("CLOUD SYNC ── MERGE FAILED — upload gate locked. Cloud data preserved unchanged.")
        if is_instance_valid(launch_status):
            launch_status.text = "Cloud save could not be applied safely. Progress preserved — try restarting."
            launch_status.add_theme_color_override("font_color", Color(1.0, 0.65, 0.35))
        return

    load_profile()  # Re-read merged result from disk into memory.
    print("CLOUD SYNC ── AFTER MERGE : gold=%d vials=%d packs=%d cards=%d trials=%d" % [
        gold_balance, dust_balance, pack_inventory, collection_owned.size(), trials_cleared.size()])
    print("CLOUD SYNC ── IN-MEMORY packs after merge = %d" % pack_inventory)

    # Unlock upload gate BEFORE applying rewards so the save inside
    # _apply_pending_column_rewards() can upload with the correct pack count.
    _cloud_safe_to_upload = true
    # Apply any admin-granted column rewards on top of the merged state.
    _apply_pending_column_rewards()

    _queue_cloud_upload.call_deferred()
    print("CLOUD SYNC ── re-uploading merged + reward-applied state to Supabase")

    # Refresh the home screen only if we are no longer on the launch screen
    # (e.g. a viewport-size change fired show_home() before this callback ran).
    if not launch_screen_active:
        show_home()

## Apply admin-granted column rewards (recovery_vials + pending_packs) from the
## Supabase player_profiles row. Called after every cloud profile apply/merge.
## Each field is zeroed on the server immediately after being applied so it is
## claimed exactly once, even if the client crashes before a full cloud upload.
func _apply_pending_column_rewards() -> void:
    var granted_vials := NetworkManager.fetched_recovery_vials
    var granted_packs := NetworkManager.fetched_pending_packs
    if granted_vials <= 0 and granted_packs <= 0:
        return

    print("CLOUD SYNC ── PENDING COLUMN REWARDS : vials=%d  packs=%d  current_vials=%d  current_packs=%d" % [
        granted_vials, granted_packs, dust_balance, pack_inventory])

    # Apply in-memory
    if granted_vials > 0:
        dust_balance  += granted_vials
        NetworkManager.fetched_recovery_vials = 0  # Prevent double-apply this session
    if granted_packs > 0:
        pack_inventory += granted_packs
        NetworkManager.fetched_pending_packs  = 0  # Prevent double-apply this session

    print("CLOUD SYNC ── IN-MEMORY AFTER REWARD : vials=%d  packs=%d" % [dust_balance, pack_inventory])

    # Persist locally and upload (upload gate must be true before this call).
    save_profile()
    print("CLOUD SYNC ── REWARD APPLIED AND SAVED : vials=%d  packs=%d" % [dust_balance, pack_inventory])

    # Zero the columns on the server so the next login doesn't re-apply.
    if not NetworkManager.user_id.is_empty() and not NetworkManager.access_token.is_empty():
        if granted_vials > 0:
            NetworkManager.clear_recovery_vials.call_deferred()
        if granted_packs > 0:
            NetworkManager.clear_pending_packs.call_deferred()

func clear_screen() -> void:
    for child in get_children(): child.queue_free()
    root_layer = Control.new()
    root_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(root_layer)

func add_background(darken := 0.36) -> void:
    var bg := TextureRect.new()
    bg.texture = load("res://assets/ui/home_bg.png")
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    root_layer.add_child(bg)
    var shade := ColorRect.new()
    shade.color = Color(0.005, 0.01, 0.025, darken)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root_layer.add_child(shade)

func style(border := GOLD_COLOR, radius := 12) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = PANEL
    s.border_color = border
    s.set_border_width_all(2)
    s.set_corner_radius_all(radius)
    s.shadow_color = Color(0,0,0,0.65)
    s.shadow_size = 8
    return s

# A handful of call sites want an actual solid highlight chip (a filled CTA
# button or a "this filter is active" tab) paired with dark text for
# contrast -- style() always keeps bg_color = PANEL (near-black) regardless
# of the border color passed in, so those call sites were pairing dark text
# with a dark background: the fill color only ever showed up as a thin
# border, and the text became nearly invisible against the panel behind it.
# The net effect read as a highlighted outline with no legible label inside
# -- an "empty bubble". This variant actually fills with the highlight
# color so dark text on top is readable.
func solid_style(fill := GOLD_COLOR, radius := 12) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = fill
    s.border_color = fill.darkened(0.25)
    s.set_border_width_all(2)
    s.set_corner_radius_all(radius)
    s.shadow_color = Color(0,0,0,0.5)
    s.shadow_size = 6
    return s

func class_color(name: String) -> Color:
    match name:
        "Hope": return Color(0.52,0.42,0.94)
        "Courage": return Color(0.92,0.28,0.20)
        "Serenity": return Color(0.25,0.72,0.86)
        "Purpose": return Color(0.80,0.58,0.20)
        _: return Color(0.55,0.80,0.55)

func button(text_value: String, pos: Vector2, size_value: Vector2, callback: Callable, parent: Control = root_layer) -> Button:
    var b := Button.new()
    b.text = text_value
    b.position = pos
    b.size = size_value
    b.add_theme_font_size_override("font_size", ui_font_size(18))
    b.add_theme_stylebox_override("normal", style(Color(0.55,0.45,0.22), 9))
    b.add_theme_stylebox_override("hover", style(GOLD_COLOR, 9))
    b.pressed.connect(callback)
    parent.add_child(b)
    return b

func label(text_value: String, pos: Vector2, size_value: Vector2, font_size := 18, parent: Control = root_layer) -> Label:
    var l := Label.new()
    l.text = text_value
    l.add_theme_font_size_override("font_size", ui_font_size(font_size))
    l.add_theme_color_override("font_color", Color(0.94,0.95,1.0))
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    # Godot computes a Control's minimum size from its UNWRAPPED single-line
    # width the instant .size is first assigned, before autowrap can narrow
    # it back down -- and Control.set_size() silently clamps up to at least
    # that minimum. Left alone, any label whose full text is wider than its
    # box (which is the whole point of using autowrap) gets force-widened
    # and never shrinks back, so the text visibly sticks out past whatever
    # card/panel/button it was supposed to fit inside. Locking
    # custom_minimum_size to the intended width *after* autowrap is set,
    # but *before* the real .size assignment below, makes Godot compute
    # wrapping against that width instead, so the box actually holds size.
    l.custom_minimum_size = Vector2(size_value.x, 0)
    l.position = pos
    l.size = size_value
    parent.add_child(l)
    return l

func header(title: String, subtitle: String) -> void:
    var p := Panel.new(); p.position=Vector2(22,16); p.size=Vector2(1236,84); p.add_theme_stylebox_override("panel",style()); root_layer.add_child(p)
    var t := label(title,Vector2(24,8),Vector2(760,38),30,p); t.add_theme_color_override("font_color",GOLD_COLOR)
    label(subtitle,Vector2(26,48),Vector2(900,25),15,p)
    button("HOME",Vector2(1080,17),Vector2(125,48),show_home,p)

func currency_bar() -> void:
    var p := Panel.new(); p.position=Vector2(846,112); p.size=Vector2(390,54); p.add_theme_stylebox_override("panel",style(Color(0.32,0.72,0.95))); root_layer.add_child(p)
    var l := label("GOLD %d   •   VIALS %d   •   PACKS %d" % [gold_balance,dust_balance,pack_inventory],Vector2(8,10),Vector2(374,34),17,p); l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER

func show_home() -> void:
    # ── First-login onboarding gate ───────────────────────────────────────────
    # Authenticated new players who have not yet chosen a starter deck are
    # intercepted here before the home screen is built.  Guest players (no
    # user_id) skip the gate so offline play is never blocked.
    if not starter_deck_selected and not NetworkManager.user_id.is_empty():
        print("ONBOARDING GATE: starter_deck_selected=false user=%s → showing deck choice" % NetworkManager.user_id)
        show_starter_deck_choice()
        return
    clear_screen()
    add_background(0.58)
    ensure_home_music()

    var active_class := selected_class if selected_class != "" else "Hope"

    # Stable 1280x720 layout. Everything stays inside fixed, non-overlapping regions.
    var top := Panel.new()
    top.position = Vector2(16, 12)
    top.size = Vector2(1248, 64)
    top.add_theme_stylebox_override("panel", style(Color(0.04, 0.06, 0.13), 12))
    root_layer.add_child(top)

    var avatar := TextureRect.new()
    avatar.texture = current_leader_texture(active_class)
    avatar.position = Vector2(10, 8)
    avatar.size = Vector2(48, 48)
    avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    avatar.clip_contents = true
    top.add_child(avatar)
    label("WALKING FREE CCG", Vector2(70, 8), Vector2(330, 28), 21, top).add_theme_color_override("font_color", GOLD_COLOR)
    # Subtitle: always shows class, appends gamer ID when set so player knows who's signed in.
    var _dn := str(NetworkManager.account_profile.get("display_name", "")).strip_edges()
    var _subtitle := "Journey's Dawn  •  " + active_class + " Leader" + ("  •  " + _dn if _dn != "" else "")
    label(_subtitle, Vector2(70, 35), Vector2(560, 21), 13, top)
    print("SHOW_HOME ── DISPLAYED : gold=%d  vials=%d  packs=%d" % [gold_balance, dust_balance, pack_inventory])
    var wallet := label("GOLD %d     VIALS %d     PACKS %d" % [gold_balance, dust_balance, pack_inventory], Vector2(750, 17), Vector2(375, 30), 16, top)
    wallet.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    button("SUPPORT", Vector2(500, 10), Vector2(110, 44), show_contact_support, top)
    button("ACCOUNT", Vector2(622, 10), Vector2(110, 44), show_account_panel, top)
    button("SETTINGS", Vector2(1140, 10), Vector2(96, 44), show_test_tools if AccessManager.role_at_least(AccessManager.ROLE_TESTER) else show_launch_screen, top)

    maybe_show_whats_new()

    var nav := Panel.new()
    nav.position = Vector2(16, 88)
    nav.size = Vector2(218, 616)
    nav.add_theme_stylebox_override("panel", style(Color(0.05, 0.07, 0.14), 14))
    root_layer.add_child(nav)
    var brand := centered_label("JOURNEY'S\nDAWN", Vector2(14, 20), Vector2(190, 72), 27, nav)
    brand.add_theme_color_override("font_color", GOLD_COLOR)
    centered_label("One day at a time.", Vector2(14, 99), Vector2(190, 28), 14, nav)
    # Grouped, labeled navigation instead of one flat stack of 8 look-alike
    # buttons: players scanning the sidebar can tell at a glance what each
    # group of actions does, and BATTLE is styled as the primary action
    # since it's the thing most players want to do most often.
    # nav_y is boxed in a Dictionary (not a bare local) because GDScript
    # `func():` lambdas capture outer locals by value at creation time, not
    # by reference — two separate lambdas each mutating a plain `var nav_y`
    # would each get their own private copy that never persists across
    # calls, causing every nav item to be drawn at the same position. A
    # Dictionary's contents are reference-shared even though the variable
    # binding itself is captured by value, so both closures see the same
    # running counter.
    var nav_state := {"y": 145.0}
    var nav_group := func(title_value: String):
        var t := label(title_value, Vector2(18, nav_state.y), Vector2(182, 16), 11, nav)
        t.add_theme_color_override("font_color", Color(0.72, 0.66, 0.48))
        nav_state.y += 18.0
    var nav_button := func(text_value: String, callback: Callable, primary: bool):
        var b := button(text_value, Vector2(14, nav_state.y), Vector2(190, 40), callback, nav)
        if primary:
            b.add_theme_stylebox_override("normal", solid_style(GOLD_COLOR, 9))
            b.add_theme_stylebox_override("hover", solid_style(GOLD_COLOR.lightened(0.15), 9))
            b.add_theme_color_override("font_color", Color(0.10, 0.07, 0.02))
            b.add_theme_color_override("font_hover_color", Color(0.10, 0.07, 0.02))
        nav_state.y += 42.0
    nav_button.call("HOME", show_home, false)
    nav_group.call("PLAY")
    nav_button.call("BATTLE", start_battle, true)
    # A slightly shorter button than nav_button's standard 42px slot -- the
    # nav column has a fixed, already-full height, and this squeezes in the
    # new Trials entry without pushing the daily-reward panel off the bottom.
    var trials_nav_btn := button("TRIALS", Vector2(14, nav_state.y), Vector2(190, 36), show_trials, nav)
    trials_nav_btn.add_theme_font_size_override("font_size", ui_font_size(17))
    nav_state.y += 38.0
    nav_button.call("DECK BUILDER", show_deck_builder, false)
    nav_button.call("STORY MODE", show_story_chapters, false)
    nav_button.call("ONLINE VS", show_online_vs_setup, false)
    nav_group.call("PROGRESS")
    nav_button.call("COLLECTION", show_collection, false)
    nav_button.call("STORE", show_store, false)
    nav_group.call("LEARN")
    nav_button.call("RECOVERY ACADEMY", show_recovery_academy, false)
    var reward := Panel.new()
    reward.position = Vector2(14, nav_state.y + 6.0)
    reward.size = Vector2(190, 36)
    reward.add_theme_stylebox_override("panel", style(Color(0.58, 0.40, 0.14), 8))
    nav.add_child(reward)
    centered_label("DAILY REWARD CLAIMED", Vector2(4, 4), Vector2(182, 26), 10, reward).add_theme_color_override("font_color", GOLD_COLOR)

    # Main content panel.
    var main := Panel.new()
    main.position = Vector2(248, 88)
    main.size = Vector2(1016, 616)
    main.add_theme_stylebox_override("panel", style(Color(0.06, 0.09, 0.17), 16))
    root_layer.add_child(main)

    # Leader portrait selector cards — shows each class's actual face so
    # the player picks by recognising the character, not just reading a word.
    var order := ["Hope", "Purpose", "Serenity", "Courage"]
    for i in range(order.size()):
        var c: String = order[i]
        var cc := class_color(c)
        var is_active := (c == active_class)

        # Card container — Panel for visual + clipping, transparent Button
        # overlay on top for click handling. Using Panel keeps clip_contents
        # rectangular so portrait art doesn't bleed past the border edges.
        var card_panel := Panel.new()
        card_panel.position = Vector2(12 + i * 249, 10)
        card_panel.size = Vector2(236, 88)
        card_panel.clip_contents = true
        var card_bg := StyleBoxFlat.new()
        card_bg.bg_color = cc.darkened(0.55) if is_active else Color(0.02, 0.03, 0.07)
        card_bg.border_color = cc
        card_bg.set_border_width_all(4 if is_active else 1)
        card_bg.set_corner_radius_all(0)
        card_bg.shadow_color = Color(cc, 0.50 if is_active else 0.0)
        card_bg.shadow_size  = 12 if is_active else 0
        card_panel.add_theme_stylebox_override("panel", card_bg)
        main.add_child(card_panel)

        # Portrait thumbnail fills top 66px of the card
        var thumb := TextureRect.new()
        thumb.texture = current_leader_texture(c)
        thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
        thumb.position = Vector2(0, 0)
        thumb.size = Vector2(236, 66)
        thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
        card_panel.add_child(thumb)

        # Bottom nameplate strip
        var nameplate := ColorRect.new()
        nameplate.color = cc.darkened(0.42) if is_active else Color(0.04, 0.06, 0.12, 0.96)
        nameplate.position = Vector2(0, 66); nameplate.size = Vector2(236, 22)
        nameplate.mouse_filter = Control.MOUSE_FILTER_IGNORE
        card_panel.add_child(nameplate)

        var name_lbl := centered_label(c.to_upper(), Vector2(0, 66), Vector2(236, 22), 13, card_panel)
        name_lbl.add_theme_color_override("font_color", cc.lightened(0.3) if is_active else Color(0.88, 0.90, 0.98))
        name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE

        # Active indicator line along the top
        if is_active:
            var ind := ColorRect.new(); ind.color = cc
            ind.position = Vector2.ZERO; ind.size = Vector2(236, 4)
            ind.mouse_filter = Control.MOUSE_FILTER_IGNORE
            card_panel.add_child(ind)

        # Transparent full-card Button on top for input — styled invisible
        var card := Button.new()
        card.position = Vector2.ZERO; card.size = Vector2(236, 88)
        var invisible := StyleBoxEmpty.new()
        card.add_theme_stylebox_override("normal",  invisible)
        card.add_theme_stylebox_override("hover",   invisible)
        card.add_theme_stylebox_override("pressed", invisible)
        card.pressed.connect(func():
            selected_class = c
            selected_deck_class = c
            save_profile()
            show_home()
        )
        card_panel.add_child(card)

    # Hero showcase — full portrait fill with dramatic glow border.
    var showcase := Panel.new()
    showcase.position = Vector2(24, 108)
    showcase.size = Vector2(548, 494)
    var showcase_style := StyleBoxFlat.new()
    showcase_style.bg_color = Color(0.008, 0.012, 0.025)
    showcase_style.border_color = class_color(active_class)
    showcase_style.set_border_width_all(5)
    showcase_style.set_corner_radius_all(18)
    showcase_style.shadow_color = Color(class_color(active_class), 0.65)
    showcase_style.shadow_size = 28
    showcase.add_theme_stylebox_override("panel", showcase_style)
    main.add_child(showcase)
    showcase.clip_contents = true

    # Inner glow lines — 2 thin accent rects along top and left inside edge
    var glow_top := ColorRect.new(); glow_top.color = Color(class_color(active_class), 0.55)
    glow_top.position = Vector2(5, 5); glow_top.size = Vector2(538, 2)
    glow_top.mouse_filter = Control.MOUSE_FILTER_IGNORE; showcase.add_child(glow_top)
    var glow_left := ColorRect.new(); glow_left.color = Color(class_color(active_class), 0.35)
    glow_left.position = Vector2(5, 5); glow_left.size = Vector2(2, 484)
    glow_left.mouse_filter = Control.MOUSE_FILTER_IGNORE; showcase.add_child(glow_left)

    var art_frame := Panel.new()
    art_frame.position = Vector2(6, 6)
    art_frame.size = Vector2(536, 482)
    art_frame.clip_contents = true
    art_frame.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
    showcase.add_child(art_frame)

    var art := TextureRect.new()
    art.texture = current_leader_texture(active_class)
    var _focal_x := float(LEADER_FOCAL_PX.get(active_class.to_lower(), 0))
    art.position = Vector2(_focal_x, 0.0)
    art.size = Vector2(art_frame.size.x + absf(_focal_x), art_frame.size.y)
    art.custom_minimum_size = Vector2.ZERO
    art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    art.mouse_filter = Control.MOUSE_FILTER_IGNORE
    art.clip_contents = true
    art_frame.add_child(art)

    # Portrait breathing animation
    var art_tween := create_tween().set_loops()
    art_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    art_tween.tween_property(art, "position:y", -8.0, 3.0)
    art_tween.tween_property(art, "position:y",  0.0, 3.0)

    # Bottom scrim — only covers the nameplate zone (bottom 28%) so the
    # portrait stays visible. Opacity kept at 0.48: dark enough to make text
    # legible, but NOT so dark that a near-black panel bg + scrim compounds to
    # solid black (the 0.78 value it replaced did exactly that).
    var scrim := ColorRect.new()
    scrim.color = Color(0.0, 0.0, 0.0, 0.0)
    scrim.position = Vector2(0, art_frame.size.y * 0.72)
    scrim.size = Vector2(art_frame.size.x, art_frame.size.y * 0.28)
    scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
    art_frame.add_child(scrim)
    # Fade scrim in via tween so it feels atmospheric rather than hard-cut
    var scrim_t := create_tween()
    scrim_t.tween_property(scrim, "color:a", 0.48, 0.6)

    # Large class nameplate overlaid at the bottom of the portrait
    var nameplate_bg := ColorRect.new()
    nameplate_bg.color = Color(class_color(active_class), 0.18)
    nameplate_bg.position = Vector2(0, art_frame.size.y - 72)
    nameplate_bg.size = Vector2(art_frame.size.x, 72)
    nameplate_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    art_frame.add_child(nameplate_bg)

    # Bright class-color line above the nameplate
    var nameplate_line := ColorRect.new()
    nameplate_line.color = class_color(active_class)
    nameplate_line.position = Vector2(0, art_frame.size.y - 74)
    nameplate_line.size = Vector2(art_frame.size.x, 3)
    nameplate_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
    art_frame.add_child(nameplate_line)

    var np_name := label(active_class.to_upper(), Vector2(20, art_frame.size.y - 68), Vector2(320, 44), 36, art_frame)
    np_name.add_theme_color_override("font_color", class_color(active_class).lightened(0.3))
    np_name.mouse_filter = Control.MOUSE_FILTER_IGNORE

    var np_desc := label(class_description(active_class), Vector2(20, art_frame.size.y - 28), Vector2(440, 22), 13, art_frame)
    np_desc.add_theme_color_override("font_color", Color(0.88, 0.91, 0.98))
    np_desc.mouse_filter = Control.MOUSE_FILTER_IGNORE

    # Pulsing class-color glow overlay
    var glow_overlay := ColorRect.new()
    glow_overlay.color = Color(class_color(active_class), 0.0)
    glow_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    glow_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    art_frame.add_child(glow_overlay)
    var glow_tween := create_tween().set_loops()
    glow_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    glow_tween.tween_property(glow_overlay, "color:a", 0.12, 2.2)
    glow_tween.tween_property(glow_overlay, "color:a", 0.02, 2.2)

    if sponsor_leader_unlocked:
        var skin_toggle := button(
            "SPONSOR SKIN: ON" if selected_leader_skin == "sponsor" else "SPONSOR SKIN: OFF",
            Vector2(16, 16), Vector2(186, 30), toggle_sponsor_skin, showcase)
        skin_toggle.add_theme_font_size_override("font_size", ui_font_size(11))

    # PREVIEW / DECKS buttons now sit at the bottom of the showcase panel (below portrait)
    var preview_button := button("PREVIEW", Vector2(40, 460), Vector2(216, 26), show_deck_preview, showcase)
    preview_button.add_theme_font_size_override("font_size", ui_font_size(13))
    var decks_button := button("DECKS", Vector2(292, 460), Vector2(216, 26), show_deck_builder, showcase)
    decks_button.add_theme_font_size_override("font_size", ui_font_size(13))

    # Right-side actions — matches new taller showcase height
    var right := Panel.new()
    right.position = Vector2(590, 108)
    right.size = Vector2(402, 494)
    right.add_theme_stylebox_override("panel", style(Color(0.06, 0.09, 0.17), 14))
    main.add_child(right)
    # Class accent header bar
    var accent_bar_r := ColorRect.new(); accent_bar_r.position = Vector2(0, 0); accent_bar_r.size = Vector2(402, 4); accent_bar_r.color = class_color(active_class); right.add_child(accent_bar_r)

    label("RECOVERY CHALLENGE", Vector2(20, 18), Vector2(362, 32), 20, right).add_theme_color_override("font_color", GOLD_COLOR)
    var challenge_progress := int(recovery_challenge_progress.get(active_class, 0))
    var wins_remaining := 3 - challenge_progress
    var challenge_line := label("Win %d more match%s with %s to complete this week's challenge." % [wins_remaining, "es" if wins_remaining != 1 else "", active_class], Vector2(20, 54), Vector2(362, 36), 14, right)
    challenge_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    var progress_bg := ColorRect.new(); progress_bg.position = Vector2(20, 98); progress_bg.size = Vector2(362, 14); progress_bg.color = Color(0.05,0.06,0.09); right.add_child(progress_bg)
    var progress := ColorRect.new(); progress.position = Vector2(20, 98); progress.size = Vector2(362.0 * (float(challenge_progress) / 3.0), 14); progress.color = class_color(active_class); right.add_child(progress)
    # Progress pip markers
    for pip in range(1, 3):
        var pip_mark := ColorRect.new(); pip_mark.position = Vector2(20 + 362.0 * pip / 3.0 - 1, 96); pip_mark.size = Vector2(2, 18); pip_mark.color = Color(0.08, 0.11, 0.20); right.add_child(pip_mark)
    label("%d / 3 wins" % challenge_progress, Vector2(20, 118), Vector2(362, 22), 12, right).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

    # Thin separator
    var sep := ColorRect.new(); sep.position = Vector2(16, 150); sep.size = Vector2(370, 1); sep.color = Color(class_color(active_class), 0.25); right.add_child(sep)

    label("DAILY REFLECTION", Vector2(20, 162), Vector2(362, 28), 16, right).add_theme_color_override("font_color", GOLD_COLOR)
    var reflection := label("Progress begins with one honest choice. Keep moving forward.", Vector2(20, 196), Vector2(362, 72), 14, right)
    reflection.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    reflection.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    var enter := button("ENTER BATTLE", Vector2(20, 316), Vector2(362, 72), start_battle, right)
    enter.add_theme_font_size_override("font_size", ui_font_size(24))
    enter.add_theme_stylebox_override("normal",  solid_style(GOLD_COLOR, 14))
    enter.add_theme_stylebox_override("hover",   solid_style(GOLD_COLOR.lightened(0.2), 14))
    enter.add_theme_stylebox_override("pressed", solid_style(GOLD_COLOR.darkened(0.15), 14))
    enter.add_theme_color_override("font_color",       Color(0.04, 0.03, 0.01))
    enter.add_theme_color_override("font_hover_color", Color(0.04, 0.03, 0.01))
    # Pulsing scale animation — draws the eye unmistakably to the main CTA
    var btn_tween := create_tween().set_loops()
    btn_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    btn_tween.tween_property(enter, "modulate", Color(1.15, 1.10, 0.85), 1.1)
    btn_tween.tween_property(enter, "modulate", Color(1.0,  1.0,  1.0),  1.1)

    var trials_cta := button("THE TRIALS", Vector2(20, 398), Vector2(362, 50), show_trials, right)
    trials_cta.add_theme_font_size_override("font_size", ui_font_size(18))

    centered_label(BUILD_NAME, Vector2(20, 566), Vector2(976, 28), 12, main).modulate = Color(0.72, 0.78, 0.86)

# ---------------------------------------------------------------------------
# Contact & Support
# ---------------------------------------------------------------------------
func show_account_panel() -> void:
    # Overlay panel — does NOT clear the home screen behind it.
    var overlay := ColorRect.new()
    overlay.color = Color(0.0, 0.0, 0.0, 0.0)
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.z_index = 600
    overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    root_layer.add_child(overlay)
    # Fade in
    var fade := create_tween()
    fade.tween_property(overlay, "color:a", 0.55, 0.15)

    var panel := Panel.new()
    panel.size = Vector2(520, 360)
    panel.position = Vector2(640 - 260, 360 - 180)
    panel.z_index = 610
    panel.add_theme_stylebox_override("panel", style(Color(0.06, 0.09, 0.18), 16))
    root_layer.add_child(panel)

    # Close when clicking outside the panel
    overlay.gui_input.connect(func(ev):
        if ev is InputEventMouseButton and ev.pressed:
            if not panel.get_rect().has_point(overlay.get_local_mouse_position()):
                overlay.queue_free(); panel.queue_free()
    )

    centered_label("MY ACCOUNT", Vector2(20, 18), Vector2(480, 28), 22, panel).add_theme_color_override("font_color", GOLD_COLOR)

    # ── Sign-in status ─────────────────────────────────────────────────────────
    var is_signed_in := not NetworkManager.user_id.is_empty()
    var status_text := "Signed in" if is_signed_in else "Not signed in"
    var status_color := Color(0.45, 1.0, 0.60) if is_signed_in else Color(1.0, 0.55, 0.35)
    var status_lbl := centered_label(status_text, Vector2(20, 54), Vector2(480, 24), 14, panel)
    status_lbl.add_theme_color_override("font_color", status_color)

    # ── Gamer ID row ───────────────────────────────────────────────────────────
    label("GAMER ID", Vector2(30, 100), Vector2(200, 22), 13, panel).add_theme_color_override("font_color", Color(0.72, 0.78, 0.90))
    label("Shown to other players and in your header.", Vector2(30, 120), Vector2(460, 20), 12, panel).add_theme_color_override("font_color", Color(0.55, 0.60, 0.70))

    var name_input := LineEdit.new()
    var current_name := str(NetworkManager.account_profile.get("display_name", "")).strip_edges()
    name_input.text = current_name
    name_input.placeholder_text = "Choose a gamer ID…"
    name_input.position = Vector2(30, 148)
    name_input.size = Vector2(340, 44)
    name_input.add_theme_font_size_override("font_size", ui_font_size(17))
    panel.add_child(name_input)

    var save_status := label("", Vector2(30, 284), Vector2(460, 24), 13, panel)
    save_status.add_theme_color_override("font_color", Color(0.45, 1.0, 0.60))

    var save_btn := button("SAVE ID", Vector2(382, 148), Vector2(108, 44), func():
        var new_name := name_input.text.strip_edges()
        if new_name.length() < 2:
            save_status.text = "Gamer ID must be at least 2 characters."
            save_status.add_theme_color_override("font_color", Color(1.0, 0.55, 0.35))
            return
        if new_name.length() > 24:
            save_status.text = "Gamer ID must be 24 characters or fewer."
            save_status.add_theme_color_override("font_color", Color(1.0, 0.55, 0.35))
            return
        save_status.text = "Saving…"
        save_status.add_theme_color_override("font_color", Color(0.72, 0.78, 0.90))
        var ok := await NetworkManager.update_display_name(new_name)
        if ok:
            save_status.text = "Gamer ID saved! ✓"
            save_status.add_theme_color_override("font_color", Color(0.45, 1.0, 0.60))
            # Refresh the home screen header to show the new name immediately.
            await get_tree().create_timer(0.8).timeout
            overlay.queue_free(); panel.queue_free()
            show_home()
        else:
            save_status.text = "Save failed — check your connection and try again."
            save_status.add_theme_color_override("font_color", Color(1.0, 0.55, 0.35))
    , panel)
    save_btn.add_theme_font_size_override("font_size", ui_font_size(14))

    # ── Divider ────────────────────────────────────────────────────────────────
    var div := ColorRect.new()
    div.color = Color(0.20, 0.25, 0.38)
    div.position = Vector2(30, 220)
    div.size = Vector2(460, 1)
    panel.add_child(div)

    # ── Sign out ───────────────────────────────────────────────────────────────
    label("Want to switch accounts or sign in on a different device?", Vector2(30, 232), Vector2(460, 20), 12, panel).add_theme_color_override("font_color", Color(0.55, 0.60, 0.70))

    var signout_btn := button("RETURN TO SIGN IN", Vector2(30, 258), Vector2(220, 44), func():
        overlay.queue_free(); panel.queue_free()
        NetworkManager.sign_out_account()
        show_launch_screen()
    , panel)
    signout_btn.add_theme_font_size_override("font_size", ui_font_size(13))

    button("CLOSE", Vector2(268, 258), Vector2(100, 44), func():
        overlay.queue_free(); panel.queue_free()
    , panel)

func show_contact_support() -> void:
    clear_screen(); add_background(0.72)
    header("CONTACT & SUPPORT", "Questions, concerns, or a bug to report? We read every message.")

    var panel := Panel.new()
    panel.position = Vector2(240, 130)
    panel.size = Vector2(800, 500)
    panel.add_theme_stylebox_override("panel", style(GOLD_COLOR, 18))
    root_layer.add_child(panel)

    centered_label("EMAIL US DIRECTLY", Vector2(30, 20), Vector2(740, 26), 16, panel).add_theme_color_override("font_color", GOLD_COLOR)
    var email_row := Panel.new()
    email_row.position = Vector2(30, 50)
    email_row.size = Vector2(740, 52)
    email_row.add_theme_stylebox_override("panel", style(Color(0.32, 0.72, 0.95), 10))
    panel.add_child(email_row)
    var email_label := centered_label(SUPPORT_EMAIL, Vector2(0, 0), Vector2(560, 52), 20, email_row)
    email_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
    var copy_btn := button("COPY", Vector2(570, 6), Vector2(160, 40), func():
        DisplayServer.clipboard_set(SUPPORT_EMAIL)
        safe_set_text(contact_status, "Email address copied.")
    , email_row)
    copy_btn.add_theme_font_size_override("font_size", ui_font_size(14))

    centered_label("OR SEND A MESSAGE FROM HERE", Vector2(30, 118), Vector2(740, 24), 14, panel).add_theme_color_override("font_color", Color(0.78, 0.85, 0.95))
    label("Question, concern, or known bug:", Vector2(30, 148), Vector2(400, 22), 13, panel).add_theme_color_override("font_color", Color(0.78, 0.85, 0.95))

    contact_message_input = TextEdit.new()
    contact_message_input.position = Vector2(30, 174)
    contact_message_input.size = Vector2(740, 220)
    contact_message_input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
    contact_message_input.placeholder_text = "Tell us what's going on — the more detail (device, class you were playing, what you expected), the faster we can fix it."
    contact_message_input.add_theme_font_size_override("font_size", ui_font_size(15))
    panel.add_child(contact_message_input)

    var send_btn := button("OPEN EMAIL WITH THIS MESSAGE", Vector2(30, 410), Vector2(400, 54), _send_contact_message, panel)
    send_btn.add_theme_font_size_override("font_size", ui_font_size(15))
    var clear_btn := button("CLEAR", Vector2(450, 410), Vector2(150, 54), func(): contact_message_input.text = "", panel)

    contact_status = centered_label("", Vector2(30, 470), Vector2(740, 24), 13, panel)
    contact_status.add_theme_color_override("font_color", Color(0.55, 1.0, 0.70))

func _send_contact_message() -> void:
    var message := contact_message_input.text.strip_edges()
    if message.is_empty():
        safe_set_text(contact_status, "Write your question, concern, or bug report first.")
        contact_status.add_theme_color_override("font_color", Color(1.0, 0.55, 0.55))
        return
    var subject := "WF Sober CCG - Feedback (build %s)" % UpdateManager.current_version
    var mailto := "mailto:%s?subject=%s&body=%s" % [SUPPORT_EMAIL, subject.uri_encode(), message.uri_encode()]
    var opened := OS.shell_open(mailto)
    if opened == OK:
        safe_set_text(contact_status, "Opening your email app with this message filled in...")
        contact_status.add_theme_color_override("font_color", Color(0.55, 1.0, 0.70))
    else:
        safe_set_text(contact_status, "Couldn't open an email app automatically — please email %s directly." % SUPPORT_EMAIL)
        contact_status.add_theme_color_override("font_color", Color(1.0, 0.55, 0.55))

# ---------------------------------------------------------------------------
# "What's New" popup — shown once per installed version, the first time the
# player reaches Home after an update. Content is authored locally in
# data/version_manifest.json (see update_manager.gd) so it never depends on
# a server being reachable.
# ---------------------------------------------------------------------------
func maybe_show_whats_new() -> void:
    if whats_new_checked_this_session:
        return
    whats_new_checked_this_session = true
    var info := UpdateManager.get_whats_new()
    var version := str(info.get("version", ""))
    if version.is_empty() or version == last_seen_whats_new_version:
        return
    var sections: Array = info.get("sections", [])
    var new_cards: Array = info.get("new_cards", [])
    var upcoming: Array = info.get("upcoming_events", [])
    var build_name := str(info.get("build_name", ""))
    # Filter any easter-egg mentions from items before showing.
    var clean_sections: Array = []
    for sec in sections:
        var clean_items: Array = []
        for item in Array(sec.get("items", [])):
            if not str(item).to_upper().contains("EASTER"):
                clean_items.append(item)
        if not clean_items.is_empty():
            var sc: Dictionary = sec.duplicate()
            sc["items"] = clean_items
            clean_sections.append(sc)
    if clean_sections.is_empty() and new_cards.is_empty() and upcoming.is_empty():
        last_seen_whats_new_version = version
        save_profile()
        return
    show_whats_new_popup(version, build_name, clean_sections, new_cards, upcoming)

# ── Category → display style lookup ───────────────────────────────────────────
# Each recognisable category name maps to an icon glyph and a header colour.
# Any category not in this table falls back to a neutral white star.
# To add a new category that always looks consistent, add an entry here.
const WHATS_NEW_CATEGORY_STYLES := {
    "New Features":    {"icon": "✦", "color": Color(0.35, 0.85, 1.00)},
    "Balance Changes": {"icon": "⚖", "color": Color(1.00, 0.82, 0.35)},
    "Bug Fixes":       {"icon": "✓", "color": Color(0.45, 1.00, 0.65)},
    "UI Improvements": {"icon": "◈", "color": Color(0.85, 0.55, 1.00)},
    "Audio / Visual":  {"icon": "♫", "color": Color(1.00, 0.62, 0.32)},
    "Audio/Visual":    {"icon": "♫", "color": Color(1.00, 0.62, 0.32)},
    "New Cards":       {"icon": "✧", "color": Color(0.95, 0.78, 0.20)},
    "Features":        {"icon": "✦", "color": Color(0.35, 0.85, 1.00)},
    "Changes & Fixes": {"icon": "✓", "color": Color(0.45, 1.00, 0.65)},
    "Upcoming":        {"icon": "◌", "color": Color(1.00, 0.83, 0.35)},
}

func show_whats_new_popup(version: String, build_name: String, sections: Array, new_cards: Array, upcoming: Array) -> void:
    # ── Scrim (blocks touch-through to underlying nav buttons) ────────────────
    var scrim := ColorRect.new()
    scrim.color = Color(0.01, 0.02, 0.05, 0.90)
    scrim.position = Vector2.ZERO
    scrim.size = Vector2(1280, 720)
    scrim.mouse_filter = Control.MOUSE_FILTER_STOP
    scrim.z_index = 950
    root_layer.add_child(scrim)

    # ── Dialog shell ──────────────────────────────────────────────────────────
    var DW := 820.0; var DH := 580.0
    var dialog := Panel.new()
    dialog.position = Vector2((1280 - DW) / 2.0, (720 - DH) / 2.0)
    dialog.size = Vector2(DW, DH)
    dialog.z_index = 951
    var dlg_style := StyleBoxFlat.new()
    dlg_style.bg_color = Color(0.05, 0.07, 0.12)
    dlg_style.border_color = GOLD_COLOR
    dlg_style.set_border_width_all(2)
    dlg_style.set_corner_radius_all(18)
    dialog.add_theme_stylebox_override("panel", dlg_style)
    scrim.add_child(dialog)

    # ── Version + build name header ───────────────────────────────────────────
    var version_tag := "v%s" % version
    if build_name != "":
        version_tag = "v%s  —  %s" % [version, build_name.to_upper()]

    centered_label("WHAT'S NEW", Vector2(50, 14), Vector2(DW - 110, 38), 28, dialog).add_theme_color_override("font_color", GOLD_COLOR)
    var ver_lbl := centered_label(version_tag, Vector2(50, 54), Vector2(DW - 110, 22), 13, dialog)
    ver_lbl.add_theme_color_override("font_color", Color(0.62, 0.70, 0.85))

    # Thin separator
    var sep := ColorRect.new()
    sep.color = Color(GOLD_COLOR.r, GOLD_COLOR.g, GOLD_COLOR.b, 0.30)
    sep.position = Vector2(30, 82)
    sep.size = Vector2(DW - 60, 1)
    dialog.add_child(sep)

    # ── Scrollable content area ───────────────────────────────────────────────
    var INNER_W := DW - 60.0   # 760
    var scroll := ScrollContainer.new()
    scroll.position = Vector2(24, 90)
    scroll.size = Vector2(DW - 48, 428)
    dialog.add_child(scroll)

    var list := VBoxContainer.new()
    list.custom_minimum_size = Vector2(INNER_W, 0)
    list.add_theme_constant_override("separation", 4)
    scroll.add_child(list)

    # ── Helper closures ───────────────────────────────────────────────────────
    var _spacer := func(h: float) -> void:
        var s := Control.new()
        s.custom_minimum_size = Vector2(INNER_W, h)
        list.add_child(s)

    var _add_section_header := func(icon_glyph: String, text_value: String, hdr_color: Color) -> void:
        _spacer.call(8)
        var row := HBoxContainer.new()
        row.custom_minimum_size = Vector2(INNER_W, 0)
        list.add_child(row)

        # Coloured left accent bar
        var accent := ColorRect.new()
        accent.custom_minimum_size = Vector2(3, 0)
        accent.size_flags_vertical = Control.SIZE_EXPAND_FILL
        accent.color = hdr_color
        row.add_child(accent)

        var pad := Control.new()
        pad.custom_minimum_size = Vector2(8, 0)
        row.add_child(pad)

        var hdr := Label.new()
        hdr.text = "%s  %s" % [icon_glyph, text_value.to_upper()]
        hdr.add_theme_font_size_override("font_size", ui_font_size(15))
        hdr.add_theme_color_override("font_color", hdr_color)
        hdr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.add_child(hdr)

        _spacer.call(2)

    var _add_bullet := func(text_value: String, item_color: Color) -> void:
        var item := Label.new()
        item.text = "    •  %s" % text_value
        item.add_theme_font_size_override("font_size", ui_font_size(14))
        item.add_theme_color_override("font_color", item_color)
        item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        item.custom_minimum_size = Vector2(INNER_W, 0)
        list.add_child(item)

    # ── Render each section from the manifest ─────────────────────────────────
    var rarity_colors := {
        "Bronze":    Color(0.72, 0.48, 0.22),
        "Silver":    Color(0.78, 0.82, 0.88),
        "Gold":      Color(0.95, 0.78, 0.20),
        "Epic":      Color(0.65, 0.30, 0.90),
        "Legendary": Color(0.95, 0.55, 0.10),
        "Platinum":  Color(0.55, 0.92, 0.98),
    }

    for sec in sections:
        var cat := str(sec.get("category", ""))
        var style_info: Dictionary = WHATS_NEW_CATEGORY_STYLES.get(cat, {"icon": "★", "color": Color(0.85, 0.85, 0.92)})
        var icon: String = str(style_info.get("icon", "★"))
        var hc: Color = style_info.get("color", Color(0.85, 0.85, 0.92))
        _add_section_header.call(icon, cat, hc)
        for item_text in Array(sec.get("items", [])):
            _add_bullet.call(str(item_text), Color(0.92, 0.93, 0.98))

    # ── New cards (pulled separately from manifest) ───────────────────────────
    if not new_cards.is_empty():
        var hc: Color = WHATS_NEW_CATEGORY_STYLES.get("New Cards", {}).get("color", GOLD_COLOR)
        _add_section_header.call("✧", "New Cards", hc)
        for card_entry in new_cards:
            var cd: Dictionary = card_entry if card_entry is Dictionary else {}
            var rarity := str(cd.get("rarity", ""))
            var rc: Color = rarity_colors.get(rarity, Color(0.85, 0.85, 0.85))
            var line := "%s  [%s · %s]" % [str(cd.get("name","?")), str(cd.get("class","?")), rarity]
            _add_bullet.call(line, rc)

    # ── Upcoming events ───────────────────────────────────────────────────────
    if not upcoming.is_empty():
        var hc: Color = WHATS_NEW_CATEGORY_STYLES.get("Upcoming", {}).get("color", Color(1.0, 0.83, 0.35))
        _add_section_header.call("◌", "Upcoming", hc)
        for entry in upcoming:
            _add_bullet.call(str(entry), Color(0.88, 0.88, 0.75))

    _spacer.call(8)

    # ── Dismiss logic (identical to previous — no background-tap to avoid
    #    touch-through onto nav buttons underneath) ───────────────────────────
    var _dismiss := func():
        if not is_instance_valid(scrim): return
        scrim.hide()
        last_seen_whats_new_version = version
        save_profile()
        scrim.queue_free()

    # ✕ in top-right corner.
    var x_btn := button("✕", Vector2(DW - 52, 10), Vector2(40, 34), _dismiss, dialog)
    x_btn.add_theme_font_size_override("font_size", ui_font_size(18))
    x_btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))

    # Separator above close button.
    var sep2 := ColorRect.new()
    sep2.color = Color(GOLD_COLOR.r, GOLD_COLOR.g, GOLD_COLOR.b, 0.22)
    sep2.position = Vector2(30, DH - 70)
    sep2.size = Vector2(DW - 60, 1)
    dialog.add_child(sep2)

    # GOT IT — bottom-centre of the dialog.
    var close_btn := button("GOT IT  ✓", Vector2((DW - 200) / 2.0, DH - 58), Vector2(200, 46), _dismiss, dialog)
    close_btn.add_theme_font_size_override("font_size", ui_font_size(16))

func show_online_vs_setup() -> void:
    clear_screen(); add_background(0.68); header("VS FRIEND — ONLINE", "Private room codes for two separate phones")
    online_hosting = false
    online_selected_class = selected_class if selected_class != "" else "Hope"
    var panel := Panel.new(); panel.position=Vector2(150,115); panel.size=Vector2(980,535); panel.add_theme_stylebox_override("panel",style(Color(0.36,0.66,0.95),20)); root_layer.add_child(panel)
    var server_title := label("ONLINE BACKEND",Vector2(55,36),Vector2(250,34),20,panel); server_title.add_theme_color_override("font_color",GOLD_COLOR)
    var backend := label("SUPABASE ONLINE SERVICE",Vector2(55,76),Vector2(870,48),22,panel); backend.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; backend.add_theme_color_override("font_color",Color(0.45,0.95,0.72))
    label("CLASS",Vector2(55,145),Vector2(160,34),20,panel).add_theme_color_override("font_color",GOLD_COLOR)
    var group := ButtonGroup.new()
    for i in range(CLASSES.size()):
        var c: String = CLASSES[i]
        var b := Button.new(); b.toggle_mode=true; b.button_group=group; b.position=Vector2(55+i*218,190); b.size=Vector2(195,70); b.text=c.to_upper(); b.add_theme_font_size_override("font_size",ui_font_size(17)); b.add_theme_stylebox_override("normal",style(class_color(c),12)); b.add_theme_stylebox_override("pressed",style(GOLD_COLOR,12)); panel.add_child(b)
        b.pressed.connect(func(): online_selected_class=c)
        if c==online_selected_class: b.button_pressed=true
    label("DECK",Vector2(55,270),Vector2(160,30),18,panel).add_theme_color_override("font_color",GOLD_COLOR)
    var deck_group := ButtonGroup.new()
    var deck_modes := [{"id":"custom","label":"MY DECK"}]
    if AccessManager.role_at_least(AccessManager.ROLE_OWNER):
        deck_modes.append({"id":"meta","label":"DEV META"})
        deck_modes.append({"id":"final_boss","label":"FINAL BOSS"})
    for i in range(deck_modes.size()):
        var mode_data: Dictionary = deck_modes[i]
        var db := Button.new(); db.toggle_mode=true; db.button_group=deck_group; db.position=Vector2(210+i*225,260); db.size=Vector2(205,48); db.text=str(mode_data["label"]); db.add_theme_font_size_override("font_size",ui_font_size(15)); db.add_theme_stylebox_override("normal",style(Color(0.28,0.40,0.62),10)); db.add_theme_stylebox_override("pressed",style(GOLD_COLOR,10)); panel.add_child(db)
        var mode_id := str(mode_data["id"])
        db.pressed.connect(func(): online_selected_deck_mode=mode_id)
        if mode_id==online_selected_deck_mode: db.button_pressed=true
    button("HOST MATCH",Vector2(55,340),Vector2(255,62),_online_host_pressed,panel)
    online_room_input = LineEdit.new(); online_room_input.position=Vector2(350,340); online_room_input.size=Vector2(250,62); online_room_input.placeholder_text="6-DIGIT CODE"; online_room_input.max_length=6; online_room_input.add_theme_font_size_override("font_size",ui_font_size(22)); online_room_input.alignment=HORIZONTAL_ALIGNMENT_CENTER; panel.add_child(online_room_input)
    button("JOIN MATCH",Vector2(630,340),Vector2(255,62),_online_join_pressed,panel)
    online_status = label("Choose a class and deck, then host or join.",Vector2(55,430),Vector2(870,55),18,panel); online_status.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    button("HOME",Vector2(40,645),Vector2(160,48),show_home)

func _connect_online_service() -> void:
    safe_set_text(online_status,"Signing in to Supabase...")
    NetworkManager.connect_service()

func _online_host_pressed() -> void:
    online_hosting = true
    if not NetworkManager.connected:
        _connect_online_service()
    else:
        NetworkManager.create_room(online_selected_class, online_selected_deck_mode)

func _online_join_pressed() -> void:
    online_hosting = false
    if online_room_input == null or online_room_input.text.strip_edges().length() != 6:
        safe_set_text(online_status,"Enter the six-digit room code.")
        return
    if not NetworkManager.connected:
        _connect_online_service()
    else:
        NetworkManager.join_room(online_room_input.text,online_selected_class, online_selected_deck_mode)

func _on_online_connected() -> void:
    if online_hosting:
        NetworkManager.create_room(online_selected_class, online_selected_deck_mode)
    elif online_room_input != null:
        NetworkManager.join_room(online_room_input.text,online_selected_class, online_selected_deck_mode)

func _on_online_room_created(code: String) -> void:
    if online_room_input != null: online_room_input.text=code
    safe_set_text(online_status,"ROOM %s — share this code. Waiting for your brother..." % code)
    NetworkManager.set_ready(online_selected_class, online_selected_deck_mode)

func _on_online_room_joined(code: String) -> void:
    safe_set_text(online_status,"Joined room %s. Waiting for host..." % code)
    NetworkManager.set_ready(online_selected_class, online_selected_deck_mode)

func _on_online_lobby_updated(payload: Dictionary) -> void:
    safe_set_text(online_status,"Room %s • Players %d/2 • Ready %d/2" % [str(payload.get("room","")),int(payload.get("players",0)),int(payload.get("ready",0))])

func _on_online_match_started(payload: Dictionary) -> void:
    var cfg := ConfigFile.new()
    cfg.set_value("battle","mode","online")
    cfg.set_value("battle","role",str(payload.get("role","join")))
    cfg.set_value("battle","room",str(payload.get("room","")))
    cfg.set_value("battle","your_class",str(payload.get("your_class",online_selected_class)))
    cfg.set_value("battle","opponent_class",str(payload.get("opponent_class","Courage")))
    cfg.set_value("battle","seed",int(payload.get("seed",1)))
    cfg.set_value("battle","your_deck_mode",str(payload.get("your_deck_mode",online_selected_deck_mode)))
    cfg.set_value("battle","opponent_deck_mode",str(payload.get("opponent_deck_mode","custom")))
    cfg.save("user://battle_setup.cfg")
    await _show_battle_intro(str(payload.get("your_class", online_selected_class)), str(payload.get("opponent_class", "Courage")))

func _on_online_error(message: String) -> void:
    safe_set_text(online_status,message)

func show_brother_battle_setup() -> void:
    clear_screen(); add_background(0.68); header("VS BROTHER", "Choose both classes, then pass the device between turns")
    var cfg := ConfigFile.new(); cfg.set_value("battle", "mode", "hotseat"); cfg.set_value("battle", "p1_class", selected_class if selected_class != "" else "Hope")
    cfg.set_value("battle", "p2_class", "Courage"); cfg.save("user://battle_setup.cfg")
    var instruction := label("PLAYER 1",Vector2(120,142),Vector2(460,42),28); instruction.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; instruction.add_theme_color_override("font_color",GOLD_COLOR)
    var instruction2 := label("PLAYER 2",Vector2(700,142),Vector2(460,42),28); instruction2.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; instruction2.add_theme_color_override("font_color",GOLD_COLOR)
    build_hotseat_class_column(Vector2(90,195), true)
    build_hotseat_class_column(Vector2(670,195), false)
    button("START BROTHER BATTLE",Vector2(455,620),Vector2(370,62),start_brother_battle)

func build_hotseat_class_column(origin: Vector2, player_one: bool) -> void:
    var group := ButtonGroup.new()
    for i in range(CLASSES.size()):
        var c: String = CLASSES[i]
        var b := Button.new(); b.toggle_mode=true; b.button_group=group; b.position=origin+Vector2((i%2)*235,(i/2)*190); b.size=Vector2(210,168)
        b.text=c.to_upper()+"\n"+class_description(c); b.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; b.add_theme_font_size_override("font_size",ui_font_size(16)); b.add_theme_stylebox_override("normal",style(class_color(c),14)); b.add_theme_stylebox_override("pressed",style(GOLD_COLOR,14))
        b.pressed.connect(func():
            var cfg := ConfigFile.new(); cfg.load("user://battle_setup.cfg"); cfg.set_value("battle", "p1_class" if player_one else "p2_class", c); cfg.save("user://battle_setup.cfg")
        )
        root_layer.add_child(b)
        if (player_one and c == (selected_class if selected_class != "" else "Hope")) or ((not player_one) and c == "Courage"):
            b.button_pressed=true

func start_brother_battle() -> void:
    get_tree().change_scene_to_file("res://battle.tscn")


func auto_claim_daily_reward_after_login() -> void:
    if not can_claim_daily_reward():
        show_home()
        return
    var today := current_calendar_day()
    var reward_index := normalized_daily_reward_index()
    var reward: Dictionary = DAILY_REWARDS[reward_index]
    pack_inventory += int(reward.get("packs", 0))
    dust_balance += int(reward.get("vials", 0))
    daily_last_claim_day = today
    daily_reward_day = (reward_index + 1) % DAILY_REWARDS.size()
    save_profile()
    show_daily_reward_claimed(reward_index, reward)

func current_calendar_day() -> int:
    return int(floor(Time.get_unix_time_from_system() / 86400.0))

func can_claim_daily_reward() -> bool:
    return current_calendar_day() != daily_last_claim_day

func normalized_daily_reward_index() -> int:
    # The five-day track repeats forever. Day 6 becomes Day 1, and missed
    # calendar days do not erase progress; the player resumes the next reward.
    return posmod(daily_reward_day, DAILY_REWARDS.size())

func show_daily_rewards() -> void:
    clear_screen(); add_background(0.68); header("DAILY RECOVERY REWARDS", "Return each day to keep building your collection"); currency_bar()
    var today_index := normalized_daily_reward_index()
    var accent := class_color(selected_class) if selected_class != "" else GOLD_COLOR

    # A connecting streak rail behind the day cards makes the five-day track
    # read as one continuous journey instead of five disconnected boxes.
    var rail := ColorRect.new()
    rail.position = Vector2(96, 296); rail.size = Vector2(1088, 6)
    rail.color = Color(0.20, 0.24, 0.30); root_layer.add_child(rail)
    var rail_progress := ColorRect.new()
    rail_progress.position = Vector2(96, 296); rail_progress.size = Vector2(1088 * (float(today_index) / max(1.0, DAILY_REWARDS.size() - 1.0)), 6)
    rail_progress.color = accent; root_layer.add_child(rail_progress)

    for i in range(DAILY_REWARDS.size()):
        var reward: Dictionary = DAILY_REWARDS[i]
        var is_today := i == today_index
        var is_claimed := (daily_last_claim_day >= 0 and i < today_index) or (is_today and not can_claim_daily_reward())
        var panel := Panel.new(); panel.position = Vector2(78 + i * 235, 205); panel.size = Vector2(205, 275)
        var border := accent if is_today else (Color(0.42,0.56,0.42) if is_claimed else Color(0.32,0.40,0.50))
        var pstyle := style(border, 16)
        if is_today:
            pstyle.set_border_width_all(4)
            pstyle.shadow_color = Color(accent, 0.45); pstyle.shadow_size = 14
        elif is_claimed:
            pstyle.bg_color = pstyle.bg_color.lightened(0.03)
        panel.add_theme_stylebox_override("panel", pstyle); root_layer.add_child(panel)
        if is_claimed:
            panel.modulate = Color(0.82, 0.86, 0.82) if not is_today else Color.WHITE

        var badge_text := "DAY %d" % (i + 1)
        var title_label := label(badge_text, Vector2(18,16), Vector2(169,36), 22, panel); title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        if is_claimed:
            title_label.add_theme_color_override("font_color", Color(0.6, 0.92, 0.62))

        var pack_icon := centered_label("\U0001F4E6", Vector2(18, 55), Vector2(169, 46), 30, panel)
        var reward_text := "%d CARD PACK%s" % [int(reward["packs"]), "" if int(reward["packs"]) == 1 else "S"]
        if int(reward["vials"]) > 0:
            reward_text += "\n+ %d VIALS" % int(reward["vials"])
        var reward_label := label(reward_text, Vector2(18,104), Vector2(169,80), 19, panel); reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; reward_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

        var state := "UP NEXT"
        if is_claimed:
            state = "\u2713 CLAIMED"
        elif is_today:
            state = "TODAY — READY"
        var state_style := StyleBoxFlat.new()
        state_style.bg_color = Color(0.20, 0.42, 0.24, 0.9) if is_claimed else (Color(accent, 0.30) if is_today else Color(0.12, 0.14, 0.18, 0.7))
        state_style.set_corner_radius_all(10)
        var state_wrap := Panel.new(); state_wrap.position = Vector2(14, 205); state_wrap.size = Vector2(177, 40)
        state_wrap.add_theme_stylebox_override("panel", state_style); panel.add_child(state_wrap)
        var state_label := label(state, Vector2(0,0), Vector2(177,40), 15, state_wrap); state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; state_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        if is_today:
            state_label.add_theme_color_override("font_color", accent.lightened(0.4))

    var claim_button := button("CLAIM TODAY'S REWARD", Vector2(460,535), Vector2(360,68), claim_daily_reward)
    claim_button.add_theme_stylebox_override("normal", style(accent, 14))
    claim_button.disabled = not can_claim_daily_reward()
    if not can_claim_daily_reward():
        safe_set_text(claim_button, "COME BACK TOMORROW")

func claim_daily_reward() -> void:
    if not can_claim_daily_reward():
        return
    var today := current_calendar_day()
    var reward_index := normalized_daily_reward_index()
    var reward: Dictionary = DAILY_REWARDS[reward_index]
    pack_inventory += int(reward.get("packs", 0))
    dust_balance += int(reward.get("vials", 0))
    daily_last_claim_day = today
    daily_reward_day = (reward_index + 1) % DAILY_REWARDS.size()
    save_profile()
    show_daily_reward_claimed(reward_index, reward)

func show_daily_reward_claimed(reward_index: int, reward: Dictionary) -> void:
    clear_screen(); add_background(0.72)
    var p := Panel.new(); p.position=Vector2(265,115); p.size=Vector2(750,500); p.add_theme_stylebox_override("panel",style(GOLD_COLOR,22)); root_layer.add_child(p)
    var t := label("DAY %d REWARD CLAIMED" % (reward_index + 1),Vector2(50,45),Vector2(650,60),34,p); t.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; t.add_theme_color_override("font_color",GOLD_COLOR)
    var reward_text := "%d CARD PACK%s" % [int(reward.get("packs",0)), "" if int(reward.get("packs",0)) == 1 else "S"]
    if int(reward.get("vials",0)) > 0:
        reward_text += "\n%d RECOVERY VIALS" % int(reward.get("vials",0))
    var r := label(reward_text,Vector2(95,150),Vector2(560,150),30,p); r.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; r.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
    label("Your next reward unlocks tomorrow.",Vector2(95,325),Vector2(560,44),19,p).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    button("RETURN HOME",Vector2(245,405),Vector2(260,58),show_home,p)

func show_first_day_intro() -> void:
    clear_screen(); add_background(0.68)
    header("CLASS TRAINING", "Choose a class, learn its growth resource, then complete a real training battle")

    var intro := centered_label("Each class grows differently. Pick the path you want to learn first.", Vector2(170, 88), Vector2(940, 48), 20)
    intro.add_theme_color_override("font_color", Color(0.96,0.91,0.72))

    var resource_names := {"Courage":"RESOLVE", "Hope":"HOPE", "Serenity":"PEACE", "Purpose":"PROGRESS"}
    var resource_text := {
        "Courage":"Build Resolve by fighting, surviving combat, and defeating enemy followers.",
        "Hope":"Build Hope through healing, recovery, and returning followers from the Relapse Zone.",
        "Serenity":"Build Peace through patience, healing, and Recovery Skills.",
        "Purpose":"Build Progress through discipline and spending your Play Points efficiently."
    }
    var battle_lessons := {
        "Courage":"TRAINING FOCUS: Trade followers, build Resolve, then spend it to seize the board.",
        "Hope":"TRAINING FOCUS: Heal, recover a follower, and outlast the opposing deck.",
        "Serenity":"TRAINING FOCUS: Play a Recovery Skill, build Peace, and grow your board through healing.",
        "Purpose":"TRAINING FOCUS: Spend all Play Points, build Progress, and reach Walking Free."
    }

    for i in range(CLASSES.size()):
        var c: String = CLASSES[i]
        var panel := Panel.new()
        panel.position = Vector2(30 + i * 310, 150)
        panel.size = Vector2(286, 465)
        panel.add_theme_stylebox_override("panel", style(class_color(c), 18))
        root_layer.add_child(panel)

        var art := TextureRect.new()
        art.texture = class_leader_texture(c)
        art.position = Vector2(45, 18)
        art.size = Vector2(196, 176)
        art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
        art.clip_contents = true
        panel.add_child(art)

        var class_title := centered_label(c.to_upper(), Vector2(18, 198), Vector2(250, 38), 25, panel)
        class_title.add_theme_color_override("font_color", class_color(c).lightened(0.25))
        var resource_title := centered_label(str(resource_names[c]), Vector2(25, 242), Vector2(236, 34), 18, panel)
        resource_title.add_theme_color_override("font_color", GOLD_COLOR)
        var resource_body := centered_label(str(resource_text[c]), Vector2(24, 280), Vector2(238, 78), 15, panel)
        resource_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        var focus := centered_label(str(battle_lessons[c]), Vector2(22, 356), Vector2(242, 62), 13, panel)
        focus.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        focus.add_theme_color_override("font_color", Color(0.80,0.88,1.0))
        var cfg := ConfigFile.new(); cfg.load(SAVE_PATH)
        var completed := bool(cfg.get_value("academy", "class_%s_complete" % c.to_lower(), false))
        var train_text := "REPLAY ✓" if completed else "TRAIN AS " + c.to_upper()
        button(train_text, Vector2(45, 420), Vector2(196, 38), func(): begin_class_training(c), panel)

    button("HOME", Vector2(560, 642), Vector2(160, 42), show_home)

func begin_class_training(class_name_value: String) -> void:
    selected_class = class_name_value
    selected_deck_class = class_name_value
    var opponent_map := {"Courage":"Serenity", "Hope":"Courage", "Serenity":"Purpose", "Purpose":"Hope"}
    var cfg := ConfigFile.new()
    cfg.set_value("battle", "mode", "training")
    cfg.set_value("battle", "your_class", class_name_value)
    cfg.set_value("battle", "opponent_class", str(opponent_map.get(class_name_value, "Courage")))
    cfg.set_value("battle", "your_deck_mode", "prebuilt")
    cfg.set_value("battle", "opponent_deck_mode", "prebuilt")
    cfg.set_value("training", "class", class_name_value)
    cfg.save("user://battle_setup.cfg")
    await _show_battle_intro(class_name_value, str(opponent_map.get(class_name_value, "Courage")))

func begin_academy() -> void:
    academy_step = 0
    academy_action_stage = 0
    show_academy_lesson()

func replay_how_to_play() -> void:
    show_recovery_academy()

func show_recovery_academy() -> void:
    clear_screen(); add_background(0.64)
    header("RECOVERY ACADEMY", "Eleven lessons — from your first card to your full strategy")
    if academy_complete:
        currency_bar()

    const LESSON_TITLES := ["THE BATTLEFIELD", "PLAY A FOLLOWER", "COMBAT", "END YOUR TURN",
        "SPELLS & AMULETS", "CARD EFFECTS & KEYWORDS", "RECOVERY & REVIVE",
        "PROVING YOURSELF", "LEADER SIGNATURE CARDS", "SPONSOR & SPONSEE", "BUILDING YOUR DECK"]
    const LESSON_SUBS := [
        "Learn the zones — leader, hand, battlefield, and play points.",
        "Spend Play Points to put a follower on the field.",
        "Select a follower and strike an enemy target.",
        "End your turn and see what changes for both players.",
        "Cast a spell for an instant effect; place an amulet for ongoing value.",
        "Discover what keywords like Charge, Guard, and Rush actually do.",
        "Use the Relapse Zone, recover a card, and see Revive in action.",
        "Spend Second Chance wisely — and use Momentum when it counts.",
        "Every leader has one card that defines their whole game plan.",
        "Play Sponsor, pick a Sponsee, and trigger the protective bond.",
        "Build a legal 40-card deck before you head to the real game.",
    ]
    const MENTOR_CLASSES := ["Hope", "Courage", "Courage", "Courage", "Serenity",
        "Purpose", "Hope", "Purpose", "Purpose", "Purpose", "Purpose"]
    const MENTOR_NAMES := ["Dawn", "Marcus", "Marcus", "Marcus", "Priya",
        "Theo", "Dawn", "Theo", "Dean Alvarez", "Theo", "Dean Alvarez"]

    var cfg := ConfigFile.new(); cfg.load(SAVE_PATH)

    var COLS := 4
    var panel_w := 286.0
    var panel_h := 172.0
    var gap_x := 20.0
    var gap_y := 16.0
    var total_w := COLS * panel_w + (COLS - 1) * gap_x
    var start_x := (1280.0 - total_w) * 0.5
    var start_y := 104.0

    for i in range(LESSON_TITLES.size()):
        var row := i / COLS
        var col := i % COLS

        var row_count_in_row := mini(COLS, LESSON_TITLES.size() - row * COLS)
        var row_w := row_count_in_row * panel_w + (row_count_in_row - 1) * gap_x
        var row_x := (1280.0 - row_w) * 0.5

        var px := row_x + col * (panel_w + gap_x)
        var py := start_y + row * (panel_h + gap_y)

        var lesson_done := academy_step > i or academy_complete
        var lesson_available := academy_step >= i or academy_complete
        var mentor_c: String = MENTOR_CLASSES[i]
        var accent := class_color(mentor_c)

        var panel := Panel.new()
        panel.position = Vector2(px, py)
        panel.size = Vector2(panel_w, panel_h)
        var sb := StyleBoxFlat.new()
        sb.bg_color = Color(accent.r, accent.g, accent.b, 0.10) if lesson_available else Color(0.06, 0.07, 0.10)
        sb.border_color = accent if lesson_available else Color(0.28, 0.30, 0.36)
        sb.set_border_width_all(3 if lesson_done else 2)
        sb.set_corner_radius_all(14)
        panel.add_theme_stylebox_override("panel", sb)
        root_layer.add_child(panel)

        # Lesson number + done badge
        var badge_text := "LESSON %d  ✓" % (i + 1) if lesson_done else "LESSON %d" % (i + 1)
        var badge_color := GOLD_COLOR if lesson_done else (Color(0.80, 0.86, 0.94) if lesson_available else Color(0.48, 0.50, 0.56))
        var badge := label(badge_text, Vector2(12, 10), Vector2(200, 20), 12, panel)
        badge.add_theme_color_override("font_color", badge_color)

        # Small mentor portrait circle
        var portrait_shell := Panel.new()
        portrait_shell.position = Vector2(panel_w - 48.0, 8.0)
        portrait_shell.size = Vector2(36, 36)
        portrait_shell.clip_contents = true
        portrait_shell.add_theme_stylebox_override("panel", style(accent.darkened(0.4), 18))
        panel.add_child(portrait_shell)
        if lesson_available:
            var port := TextureRect.new()
            port.texture = class_leader_texture(mentor_c)
            port.position = Vector2(2, 2)
            port.size = Vector2(32, 32)
            port.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
            port.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
            port.clip_contents = true
            port.mouse_filter = Control.MOUSE_FILTER_IGNORE
            portrait_shell.add_child(port)

        # Title
        var title_lbl := label(LESSON_TITLES[i], Vector2(12, 32), Vector2(panel_w - 24.0, 30), 16, panel)
        title_lbl.add_theme_color_override("font_color", accent.lightened(0.35) if lesson_available else Color(0.50, 0.52, 0.58))

        # Subtitle
        var sub := label(LESSON_SUBS[i], Vector2(12, 66), Vector2(panel_w - 24.0, 52), 12, panel)
        sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        sub.add_theme_color_override("font_color", Color(0.72, 0.76, 0.84) if lesson_available else Color(0.40, 0.42, 0.48))

        # Mentor credit
        var mentor_lbl := label(MENTOR_NAMES[i], Vector2(12, panel_h - 38.0), Vector2(140, 18), 11, panel)
        mentor_lbl.add_theme_color_override("font_color", accent.lightened(0.2) if lesson_available else Color(0.38, 0.40, 0.46))

        # Action button
        var btn_text := "REPLAY" if lesson_done else ("START" if lesson_available else "🔒 LOCKED")
        var i_capture := i
        var btn := button(btn_text, Vector2(panel_w - 118.0, panel_h - 42.0), Vector2(106, 34), func():
            academy_step = i_capture
            academy_action_stage = 0
            show_academy_lesson()
        , panel)
        btn.disabled = not lesson_available
        btn.add_theme_font_size_override("font_size", ui_font_size(13))
        if lesson_available:
            var btn_sb := StyleBoxFlat.new()
            btn_sb.bg_color = Color(accent.r, accent.g, accent.b, 0.30)
            btn_sb.border_color = accent; btn_sb.set_border_width_all(2); btn_sb.set_corner_radius_all(9)
            var btn_sb_h := StyleBoxFlat.new()
            btn_sb_h.bg_color = Color(accent.r, accent.g, accent.b, 0.65)
            btn_sb_h.border_color = accent.lightened(0.3); btn_sb_h.set_border_width_all(2); btn_sb_h.set_corner_radius_all(9)
            btn.add_theme_stylebox_override("normal", btn_sb)
            btn.add_theme_stylebox_override("hover", btn_sb_h)

    button("HOME", Vector2(40, 650), Vector2(180, 48), show_home)

func centered_label(text_value: String, pos: Vector2, size_value: Vector2, font_size := 18, parent: Control = root_layer) -> Label:
    var l := label(text_value, pos, size_value, font_size, parent)
    l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    return l

func academy_card(title_text: String, subtitle: String, pos: Vector2, border: Color, callback: Callable, parent: Control) -> Button:
    var b := button(title_text + "\n" + subtitle, pos, Vector2(180, 118), callback, parent)
    b.add_theme_font_size_override("font_size", ui_font_size(16))
    b.add_theme_stylebox_override("normal", style(border, 14))
    b.add_theme_stylebox_override("hover", style(border.lightened(0.22), 14))
    return b

func academy_feedback_text(text_value: String, positive := true) -> void:
    if academy_feedback != null and is_instance_valid(academy_feedback):
        academy_feedback.text = text_value
        academy_feedback.add_theme_color_override("font_color", Color(0.55, 1.0, 0.70) if positive else Color(1.0, 0.55, 0.55))

func show_tutorial_class_picker(tutorial_lesson: int) -> void:
    # Scrim behind the picker
    var scrim := ColorRect.new()
    scrim.color = Color(0.01, 0.02, 0.05, 0.88)
    scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    scrim.mouse_filter = Control.MOUSE_FILTER_STOP
    scrim.z_index = 900
    root_layer.add_child(scrim)

    var dialog := Panel.new()
    dialog.position = Vector2(140, 120)
    dialog.size = Vector2(1000, 480)
    dialog.z_index = 901
    dialog.add_theme_stylebox_override("panel", style(GOLD_COLOR, 20))
    scrim.add_child(dialog)

    centered_label("CHOOSE YOUR CLASS", Vector2(0, 18), Vector2(1000, 36), 26, dialog).add_theme_color_override("font_color", GOLD_COLOR)
    centered_label("Pick a leader to play this lesson as.", Vector2(0, 54), Vector2(1000, 24), 14, dialog).modulate = Color(0.78, 0.84, 0.94)

    for i in range(CLASSES.size()):
        var c: String = CLASSES[i]
        var col := class_color(c)

        var card := Panel.new()
        card.position = Vector2(20 + i * 242, 90)
        card.size = Vector2(228, 360)
        card.clip_contents = false
        var card_sb := StyleBoxFlat.new()
        card_sb.bg_color = Color(col.r, col.g, col.b, 0.12)
        card_sb.border_color = col
        card_sb.set_border_width_all(3)
        card_sb.set_corner_radius_all(14)
        card.add_theme_stylebox_override("panel", card_sb)
        dialog.add_child(card)

        # Leader portrait
        var art_shell := Panel.new()
        art_shell.position = Vector2(8, 8)
        art_shell.size = Vector2(212, 236)
        art_shell.clip_contents = true
        art_shell.add_theme_stylebox_override("panel", style(col.darkened(0.55), 10))
        card.add_child(art_shell)
        var art := TextureRect.new()
        art.texture = class_leader_texture(c)
        art.position = Vector2(4, 4)
        art.size = Vector2(204, 228)
        art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
        art.clip_contents = true
        art.mouse_filter = Control.MOUSE_FILTER_IGNORE
        art_shell.add_child(art)

        # Class name
        var name_lbl := centered_label(c.to_upper(), Vector2(0, 252), Vector2(228, 32), 18, card)
        name_lbl.add_theme_color_override("font_color", col.lightened(0.3))

        # Short description
        var desc := centered_label(class_description(c), Vector2(10, 286), Vector2(208, 48), 12, card)
        desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

        # Select button
        var sel_sb_n := StyleBoxFlat.new()
        sel_sb_n.bg_color = Color(col.r, col.g, col.b, 0.30)
        sel_sb_n.border_color = col; sel_sb_n.set_border_width_all(2); sel_sb_n.set_corner_radius_all(10)
        var sel_sb_h := StyleBoxFlat.new()
        sel_sb_h.bg_color = Color(col.r, col.g, col.b, 0.75)
        sel_sb_h.border_color = col.lightened(0.3); sel_sb_h.set_border_width_all(2); sel_sb_h.set_corner_radius_all(10)
        var sel_btn := Button.new()
        sel_btn.text = "PLAY AS %s" % c.to_upper()
        sel_btn.position = Vector2(14, 340)
        sel_btn.size = Vector2(200, 42)
        sel_btn.add_theme_font_size_override("font_size", ui_font_size(13))
        sel_btn.add_theme_stylebox_override("normal", sel_sb_n)
        sel_btn.add_theme_stylebox_override("hover", sel_sb_h)
        sel_btn.pressed.connect(func():
            selected_class = c
            scrim.queue_free()
            launch_tutorial_battle(tutorial_lesson)
        )
        card.add_child(sel_btn)

func launch_tutorial_battle(tutorial_lesson: int) -> void:
    stop_home_music()
    var player_class: String = selected_class if selected_class != "" else "Hope"
    var cfg := ConfigFile.new()
    cfg.set_value("battle", "mode", "tutorial")
    cfg.set_value("tutorial", "lesson", tutorial_lesson)
    cfg.set_value("tutorial", "player_class", player_class)
    cfg.set_value("tutorial", "lesson_complete", false)
    cfg.save("user://battle_setup.cfg")
    get_tree().change_scene_to_file("res://battle.tscn")

func show_academy_lesson() -> void:
    # Lessons 1-4, 6, and 9 run inside the real battle scene with followers
    # on the field. Map academy_step → tutorial_lesson index and skip the UI.
    const BATTLE_STEPS := {0: 0, 1: 1, 2: 2, 3: 3, 4: 4, 6: 5, 9: 6}
    if BATTLE_STEPS.has(academy_step):
        # Build the static lesson screen first so the class picker has something
        # to sit on top of, then immediately show the picker as an overlay.
        # The picker's confirm button calls launch_tutorial_battle() directly.
        clear_screen(); add_background(0.68)
        show_tutorial_class_picker(BATTLE_STEPS[academy_step])
        return
    clear_screen(); add_background(0.68)
    academy_action_stage = 0
    # Lesson order used to open with "Proving Yourself" (Second Chance +
    # Momentum) -- a discard-for-value trade-off with real cost math -- as
    # the very first thing a brand-new player saw, before they'd learned
    # what a zone, a follower, or even a turn was. That's the single
    # biggest source of "the tutorial is confusing": it led with an
    # advanced, high-complexity mechanic instead of orientation. Order is
    # now: get your bearings (battlefield) -> take the most basic action
    # (play a follower) -> combat -> end turn -> the other card types
    # (spells/amulets, keywords) -> Recovery & Revive (introduces the
    # Relapse Zone and revival, which Proving Yourself now builds on
    # instead of preceding) -> Proving Yourself -> the higher-strategy
    # lessons (signature cards, sponsor) -> deck building last, as the
    # capstone right before a player would actually go build one.
    var lesson_titles := ["THE BATTLEFIELD", "PLAY A FOLLOWER", "COMBAT", "END YOUR TURN", "SPELLS & AMULETS", "CARD EFFECTS & KEYWORDS", "RECOVERY & REVIVE", "PROVING YOURSELF", "LEADER SIGNATURE CARDS", "SPONSOR & SPONSEE", "BUILDING YOUR DECK"]
    # Mentors now have actual names, not just job titles -- giving every lesson
    # a consistent character voice instead of a faceless role label. The role
    # titles are kept as a separate array (mentor_titles) purely so the
    # portrait-lookup logic below (which matches a title's first word against
    # CLASSES) keeps working unchanged.
    var mentor_names := ["Dawn", "Marcus", "Marcus", "Marcus", "Priya", "Theo", "Dawn", "Theo", "Dean Alvarez", "Theo", "Dean Alvarez"]
    var mentor_titles := ["Hope Mentor", "Courage Veteran", "Courage Veteran", "Courage Veteran", "Serenity Guardian", "Purpose Champion", "Hope Mentor", "Purpose Champion", "Recovery Academy Dean", "Purpose Champion", "Recovery Academy Dean"]
    var lesson_class: String = CLASSES[academy_step % CLASSES.size()]
    var accent := class_color(lesson_class)
    header(lesson_titles[academy_step], "Lesson %d of %d • %s, %s" % [academy_step + 1, ACADEMY_LESSON_COUNT, mentor_names[academy_step], mentor_titles[academy_step]])

    # Mentor portrait chip layered onto the header, so each lesson has a face
    # attached to its voice instead of just a name in small text — the header
    # itself stays untouched since it's shared by every other screen.
    var mentor_chip := Panel.new()
    mentor_chip.position = Vector2(890, 24)
    mentor_chip.size = Vector2(68, 68)
    mentor_chip.add_theme_stylebox_override("panel", style(accent, 34))
    root_layer.add_child(mentor_chip)
    var mentor_class: String = mentor_titles[academy_step].split(" ")[0]
    var mentor_portrait := TextureRect.new()
    mentor_portrait.texture = class_leader_texture(mentor_class if mentor_class in CLASSES else lesson_class)
    mentor_portrait.position = Vector2(6, 6)
    mentor_portrait.size = Vector2(56, 56)
    mentor_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    mentor_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    mentor_portrait.clip_contents = true
    mentor_chip.add_child(mentor_portrait)

    # Eight-segment lesson tracker between the header and the board — a
    # constant, at-a-glance sense of progress through the Academy instead of
    # only a "Lesson X of 8" string buried in small subtitle text.
    var tracker := HBoxContainer.new()
    tracker.position = Vector2(95, 104)
    tracker.size = Vector2(1090, 14)
    tracker.add_theme_constant_override("separation", 8)
    root_layer.add_child(tracker)
    var seg_w: float = (1090.0 - float(ACADEMY_LESSON_COUNT - 1) * 8.0) / float(ACADEMY_LESSON_COUNT)
    for i in range(ACADEMY_LESSON_COUNT):
        var segment := ColorRect.new()
        segment.custom_minimum_size = Vector2(seg_w, 8)
        segment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        if i < academy_step:
            segment.color = accent
        elif i == academy_step:
            segment.color = accent.lightened(0.35)
        else:
            segment.color = Color(1, 1, 1, 0.12)
        tracker.add_child(segment)

    var board := Panel.new()
    board.position = Vector2(95, 126)
    # Was 535 tall, ending at y=661 on a 720-tall screen — the heavily
    # darkened background (add_background(0.68)) showed through that leftover
    # 59px strip as a near-black band, making the lesson panel look like it
    # was floating above the bottom of the screen instead of sitting on it.
    # Extending it to the same ~20px bottom margin every other screen's
    # footer leaves closes that gap.
    board.size = Vector2(1090, 574)
    board.add_theme_stylebox_override("panel", style(accent, 20))
    root_layer.add_child(board)

    # A soft interior header strip using the lesson's class color gives the
    # board depth instead of a single flat fill from edge to edge.
    var glow := ColorRect.new()
    glow.position = Vector2(0, 0)
    glow.size = Vector2(1090, 96)
    glow.color = Color(accent.r, accent.g, accent.b, 0.14)
    glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
    board.add_child(glow)
    board.move_child(glow, 0)

    # Every lesson previously showed the mentor's name and portrait but never
    # actually gave them a voice -- the "teaching" was just a dry mechanical
    # instruction line ("Click X, then click Y") with nothing tying it back
    # to who's supposedly teaching it or why it matters. A short in-character
    # line from that lesson's mentor, shown above the mechanical objective,
    # gives every lesson an actual point beyond "click the highlighted thing."
    var mentor_lines := [
        "Alright, deep breath. Before you throw a single punch, let's just look around — the ground you're standing on is the same ground that gets you through the bad days too.",
        "Nobody walks in here alone, kid. Every follower you drop on that field showed up for you — so show up for them. Two Play Points, one big first step.",
        "Courage isn't swinging wild. Clear the guy in your way first, then go for the real target. Sequence matters — in cards, and in life.",
        "Ending your turn isn't quitting — it's surviving to the next one. Watch what actually happens when the clock resets. It's more than you'd think.",
        "Some fixes are quick — a spell, a deep breath, gone in a second. Real progress is slower, and it compounds. Let me show you both.",
        "Words on a card aren't decoration, they're instructions. Learn to actually read them and nothing on this board will ever blindside you again.",
        "A setback sends you to the Relapse Zone — but that zone has a door out. Watch what happens when I go get someone back.",
        "Second Chances are real, but they're not free — you hand your opponent an opening every time you take one. Spend them like you mean it.",
        "Every leader who's ever walked through this Academy has one card that says exactly who they are. Go find yours.",
        "Nobody graduates from this alone. A Sponsor takes the hit meant for you — that's the whole bond, right there.",
        "Last stop before the real world: forty cards, your rules, your program. Get this part right and everything else takes care of itself.",
    ]
    var instruction := centered_label("", Vector2(70, 28), Vector2(950, 52), 22, board)
    instruction.add_theme_color_override("font_color", Color(0.96,0.93,0.82))

    var feedback_chip := Panel.new()
    feedback_chip.position = Vector2(170, 452)
    feedback_chip.size = Vector2(750, 56)
    feedback_chip.pivot_offset = feedback_chip.size * 0.5
    feedback_chip.add_theme_stylebox_override("panel", style(Color(accent.r, accent.g, accent.b, 0.55), 14))
    board.add_child(feedback_chip)
    academy_feedback_chip = feedback_chip
    academy_feedback = centered_label("Complete the highlighted actions to continue.", Vector2(20, 0), Vector2(710, 56), 18, feedback_chip)

    match academy_step:
        0:
            instruction.text = "Learn the battlefield by selecting each important zone."
            build_zone_lesson(board)
        1:
            instruction.text = "Spend Play Points to place a follower onto the battlefield."
            build_play_follower_lesson(board)
        2:
            instruction.text = "Attack an enemy follower, then finish by striking the enemy leader."
            build_combat_lesson(board)
        3:
            instruction.text = "End your turn and see exactly what changes for both players."
            build_end_turn_lesson(board)
        4:
            instruction.text = "Cast a spell for an immediate effect, then play Purpose's real Amulet for ongoing value."
            build_spell_amulet_lesson(board)
        5:
            instruction.text = "Reveal each keyword to learn what it does, using a real card as the example."
            build_keyword_lesson(board)
        6:
            instruction.text = "Move a follower to the Relapse Zone, recover it, then see how overdraw is Revived."
            build_recovery_lesson(board)
        7:
            instruction.text = "Use Second Chance, understand its cost, then spend Momentum yourself."
            build_second_chance_lesson(board)
        8:
            instruction.text = "Reveal each leader's signature card — the one card that defines their whole strategy."
            build_signature_lesson(board)
        9:
            instruction.text = "Play Sponsor, choose a Sponsee, and trigger the protective bond."
            build_sponsor_lesson(board)
        10:
            instruction.text = "Learn the rules for building a legal deck before you head to the Deck Builder."
            build_deck_building_lesson(board)

    # Every lesson used to just snap into view the instant clear_screen() ran,
    # which made stepping through the Academy feel like flipping slides
    # instead of walking through a guided sequence. A quick fade-in on the
    # freshly-built root_layer gives each lesson a soft entrance instead of a
    # hard cut, without touching any of the interactive logic above.
    root_layer.modulate.a = 0.0
    var lesson_in := create_tween()
    lesson_in.tween_property(root_layer, "modulate:a", 1.0, 0.28)

func build_second_chance_lesson(board: Control) -> void:
    # Explicit up-front reference for the discard-count -> Momentum scaling,
    # instead of only revealing it reactively after each click -- the whole
    # point of "how it works" is knowing the cost before you commit to it.
    var scale_note := centered_label(
        "Second Chance lets you throw away as many cards as you want and draw new ones — but every card you discard hands your opponent Momentum:\n0-1 discarded → 0 Momentum      2-3 discarded → 1 Momentum      4+ discarded → 2 Momentum",
        Vector2(50, 15), Vector2(990, 62), 15, board)
    scale_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    scale_note.add_theme_color_override("font_color", Color(0.90, 0.85, 0.65))

    var selected: Array[int] = []
    var card_buttons: Array[Button] = []
    var controls := {"confirm": null, "momentum": null}
    var costs := [8, 7, 6, 2]
    var names := ["Purpose Eternal", "Architect of Tomorrow", "Grand Design", "Vision Board"]

    for i in range(4):
        var index := i
        var b := academy_card(names[i], "%d PP" % costs[i], Vector2(105 + i * 220, 130), class_color("Purpose"), func():
            if academy_action_stage != 0:
                return
            var target: Button = null
            if index >= 0 and index < card_buttons.size():
                target = card_buttons[index]
            if selected.has(index):
                selected.erase(index)
                if is_instance_valid(target):
                    target.modulate = Color.WHITE
            else:
                selected.append(index)
                if is_instance_valid(target):
                    target.modulate = Color(0.58, 0.86, 1.0)
            var momentum_value := 0 if selected.size() <= 1 else (1 if selected.size() <= 3 else 2)
            academy_feedback_text("%d selected • Opponent would gain %d Momentum." % [selected.size(), momentum_value])
            var confirm_button = controls.get("confirm")
            if is_instance_valid(confirm_button):
                confirm_button.disabled = selected.is_empty()
        , board)
        card_buttons.append(b)

    var momentum_button := button("MOMENTUM LOCKED", Vector2(420, 370), Vector2(250, 62), func():
        if academy_action_stage != 1:
            return
        academy_action_stage = 2
        var current_momentum = controls.get("momentum")
        if is_instance_valid(current_momentum):
            current_momentum.disabled = true
            current_momentum.text = "MOMENTUM USED  ✓"
        academy_feedback_text("Momentum gives +1 temporary Play Point for one turn. Proving Yourself complete.")
        call_deferred("lesson_complete")
    , board)
    momentum_button.disabled = true
    controls["momentum"] = momentum_button

    var confirm_button := button("USE SECOND CHANCE", Vector2(370, 285), Vector2(350, 65), func():
        if academy_action_stage != 0 or selected.is_empty():
            return
        academy_action_stage = 1
        for i in range(card_buttons.size()):
            var card_button := card_buttons[i]
            if not is_instance_valid(card_button):
                continue
            if selected.has(i):
                card_button.text = "REPLACED\n↻ NEW CARD"
                card_button.modulate = Color(0.70, 1.0, 0.76)
            card_button.disabled = true
        var current_confirm = controls.get("confirm")
        if is_instance_valid(current_confirm):
            current_confirm.disabled = true
        var momentum_value := 0 if selected.size() <= 1 else (1 if selected.size() <= 3 else 2)
        academy_feedback_text("Second Chance complete. The opponent earned %d Momentum. Now activate Momentum." % momentum_value)
        var current_momentum = controls.get("momentum")
        if is_instance_valid(current_momentum):
            current_momentum.disabled = false
            current_momentum.text = "ACTIVATE MOMENTUM\n+1 TEMPORARY PP"
    , board)
    confirm_button.disabled = true
    controls["confirm"] = confirm_button

# One in-character closing line per lesson, in the same mentor's voice as
# that lesson's opening line in show_academy_lesson() -- shown as the
# celebration beat in lesson_complete() so finishing a lesson lands as a
# small scripted moment instead of the flow just quietly advancing.
const ACADEMY_CLOSING_LINES := [
    "Now you know this board better than most people know their own kitchen. Nice work.",
    "That's it — that's the whole game in one click. You just played your first card like you meant it.",
    "Clean trade, clean hit. That's how you close a fight without losing yourself in it.",
    "See? The turn ends, but you don't. Onward.",
    "One quick win, one slow burn — you just ran both playbooks. Not bad for your first spell and amulet.",
    "Keywords cracked. You'll never squint at card text again.",
    "Nobody's really gone until they choose to be. Recovery witnessed.",
    "You paid the cost and took the swing anyway. That's Proving Yourself, right there.",
    "Four leaders, four signatures, zero doubt about who you want to play.",
    "That's the bond. Somebody had your back — remember to return the favor.",
    "Forty cards, your program, your call. Go build something that's really you.",
]

func lesson_complete() -> void:
    print("ACADEMY: lesson_complete called [step=%d, in_progress=%s]" % [academy_step, str(academy_transition_in_progress)])
    if academy_transition_in_progress:
        print("ACADEMY: duplicate completion ignored [step=%d]" % academy_step)
        return
    # Snapshot the step NOW before any await — a second call arriving during
    # the animation delay will be blocked by academy_transition_in_progress
    # (set inside complete_academy_lesson_once), so completing_step stays valid.
    var completing_step := academy_step
    var closing_line: String = ACADEMY_CLOSING_LINES[completing_step] if completing_step < ACADEMY_CLOSING_LINES.size() else "Lesson complete — moving forward."
    academy_feedback_text("✓ %s" % closing_line)

    # A quick gold pulse on the feedback chip itself turns "the text changed"
    # into an actual celebration beat -- and a small burst of sparkles off
    # the same chip reuses the game's existing reward-sparkle visual language
    # (also used for pack reveals) instead of inventing a new effect.
    if is_instance_valid(academy_feedback_chip):
        var chip := academy_feedback_chip
        var pulse := create_tween()
        pulse.tween_property(chip, "scale", Vector2(1.04, 1.18), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        pulse.tween_property(chip, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
        spawn_reward_sparkles(chip.global_position + chip.size * 0.5, 10, [GOLD_COLOR, Color(1, 1, 1)], 70.0)

    # Give the player a moment to actually read the closing line before the
    # screen moves on, then fade the whole lesson out rather than cutting
    # straight to the next one. Fixed-duration timers are used instead of
    # awaiting tween.finished, since a tween killed by an in-flight scene
    # change here would otherwise hang this await forever and soft-lock the
    # Academy on this screen.
    await get_tree().create_timer(0.95).timeout
    if is_instance_valid(root_layer):
        var lesson_out := create_tween()
        lesson_out.tween_property(root_layer, "modulate:a", 0.0, 0.22)
    await get_tree().create_timer(0.22).timeout

    complete_academy_lesson_once(completing_step)

# Single authoritative function that owns Academy step advancement.
# All completion paths — UI lessons and battle-lesson returns — must call
# this instead of touching academy_step or save_profile() directly.
# The guard prevents double-advancement if a button fires twice or if
# lesson_complete() is called while a transition is already in flight.
func complete_academy_lesson_once(completed_step: int) -> void:
    if academy_transition_in_progress:
        print("ACADEMY: duplicate completion ignored [step=%d]" % completed_step)
        return
    if completed_step != academy_step:
        print("ACADEMY: completion rejected — step mismatch (completed=%d academy_step=%d)" % [completed_step, academy_step])
        return
    academy_transition_in_progress = true
    print("ACADEMY: completion accepted [step=%d]" % completed_step)

    academy_step = clampi(completed_step + 1, 0, ACADEMY_LESSON_COUNT)
    academy_action_stage = 0
    save_profile()
    print("ACADEMY: progress saved [next_step=%d]" % academy_step)

    # Ensure the screen is fully visible before building the next lesson —
    # lesson_complete() fades it to 0; the battle-return path never touched it.
    if is_instance_valid(root_layer):
        root_layer.modulate.a = 1.0

    if academy_step >= ACADEMY_LESSON_COUNT:
        print("ACADEMY: graduation loaded")
        show_academy_graduation()
    else:
        print("ACADEMY: next lesson loaded [step=%d]" % academy_step)
        show_academy_lesson()

    academy_transition_in_progress = false

func build_zone_lesson(board: Control) -> void:
    var why := {
        "leader": "Your leader has 20 Defense — when it hits 0, the match is over.",
        "hand": "Your hand holds the cards you can play this turn.",
        "deck": "Your deck is your supply. Run out and you can't draw.",
        "relapse": "Fallen followers go here — Recovery can bring them back.",
        "points": "Play Points are spent to play cards. You gain 1 more each turn.",
    }
    var icons := {"leader":"♥", "hand":"🃏", "deck":"📦", "relapse":"💀", "points":"⚡"}
    var labels := {"leader":"LEADER\n20 Defense", "hand":"YOUR HAND\nCards available", "deck":"YOUR DECK\nCards remaining", "relapse":"RELAPSE ZONE\nFallen followers", "points":"PLAY POINTS\n3 / 3"}
    var zone_colors := {
        "leader": Color(0.72, 0.18, 0.18),
        "hand":   Color(0.20, 0.48, 0.72),
        "deck":   Color(0.28, 0.55, 0.28),
        "relapse":Color(0.45, 0.18, 0.55),
        "points": Color(0.72, 0.60, 0.10),
    }
    var selected := {"leader":false, "hand":false, "deck":false, "relapse":false, "points":false}
    var counter := [0]
    # b_refs boxes each button so the callback can reference it after assignment.
    var b_refs: Dictionary = {}

    var make_zone := func(pos: Vector2, key: String):
        var tile := Panel.new()
        tile.position = pos
        tile.size = Vector2(195, 88)
        var zc: Color = zone_colors[key]
        var sb := StyleBoxFlat.new()
        sb.bg_color = Color(zc.r, zc.g, zc.b, 0.22)
        sb.border_color = zc
        sb.set_border_width_all(3)
        sb.corner_radius_top_left = 12; sb.corner_radius_top_right = 12
        sb.corner_radius_bottom_left = 12; sb.corner_radius_bottom_right = 12
        tile.add_theme_stylebox_override("panel", sb)
        tile.mouse_filter = Control.MOUSE_FILTER_STOP
        board.add_child(tile)
        b_refs[key] = tile

        var icon_lbl := Label.new()
        icon_lbl.text = icons[key]
        icon_lbl.position = Vector2(10, 8)
        icon_lbl.size = Vector2(36, 36)
        icon_lbl.add_theme_font_size_override("font_size", 24)
        icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
        tile.add_child(icon_lbl)

        var name_lbl := Label.new()
        name_lbl.text = labels[key]
        name_lbl.position = Vector2(46, 8)
        name_lbl.size = Vector2(140, 72)
        name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        name_lbl.add_theme_font_size_override("font_size", 14)
        name_lbl.add_theme_color_override("font_color", Color(0.96, 0.93, 0.82))
        name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
        tile.add_child(name_lbl)

        tile.gui_input.connect(func(ev: InputEvent):
            if not (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT): return
            if selected[key]: return
            selected[key] = true
            counter[0] += 1
            var t: Panel = b_refs.get(key)
            if is_instance_valid(t):
                var done_sb := StyleBoxFlat.new()
                done_sb.bg_color = Color(zc.r, zc.g, zc.b, 0.65)
                done_sb.border_color = Color(0.6, 1.0, 0.6)
                done_sb.set_border_width_all(3)
                done_sb.corner_radius_top_left = 12; done_sb.corner_radius_top_right = 12
                done_sb.corner_radius_bottom_left = 12; done_sb.corner_radius_bottom_right = 12
                t.add_theme_stylebox_override("panel", done_sb)
                if is_instance_valid(icon_lbl): icon_lbl.text = "✓"
            academy_feedback_text("%s  (%d / 5)" % [why.get(key, ""), counter[0]])
            if counter[0] == 5:
                await get_tree().create_timer(0.4).timeout
                lesson_complete()
        )

    make_zone.call(Vector2(80,  110), "leader")
    make_zone.call(Vector2(310, 110), "hand")
    make_zone.call(Vector2(795, 110), "deck")
    make_zone.call(Vector2(795, 300), "relapse")
    make_zone.call(Vector2(80,  300), "points")

func build_play_follower_lesson(board: Control) -> void:
    centered_label("PLAY POINTS: 2 / 2", Vector2(65, 122), Vector2(220, 54), 22, board)
    var field := Panel.new(); field.position=Vector2(390,126); field.size=Vector2(310,180); field.add_theme_stylebox_override("panel",style(Color(0.25,0.65,0.45),16)); board.add_child(field)
    centered_label("YOUR BATTLEFIELD\n(empty)",Vector2(20,45),Vector2(270,90),20,field)
    var card: Button
    card = academy_card("NEWCOMER", "2 Cost • 2/2", Vector2(130, 280), class_color("Hope"), func():
        if academy_action_stage != 0: return
        academy_action_stage = 1
        if is_instance_valid(card):
            card.disabled = true
            card.text = "NEWCOMER\nPLAYED ✓"
        var field_label := field.get_child(0) if field.get_child_count() > 0 else null
        safe_set_text(field_label, "NEWCOMER\n2 ATTACK • 2 DEFENSE")
        academy_feedback_text("You spent 2 Play Points and placed a follower. Followers normally wait one turn before attacking.")
        await get_tree().create_timer(0.8).timeout
        lesson_complete()
    , board)
    centered_label("Click the card to play it.", Vector2(340, 354), Vector2(410, 40), 18, board)

func build_combat_lesson(board: Control) -> void:
    var ally: Button
    ally = academy_card("COURAGE ROOKIE", "3/3 • Ready", Vector2(160, 270), class_color("Courage"), func():
        academy_feedback_text("Pick a target first — I like where your head's at, but there's nothing to hit yet.", false)
    , board)
    var enemy: Button
    enemy = academy_card("ENEMY GUARD", "2/2", Vector2(455, 125), Color(0.85,0.30,0.25), func():
        if academy_action_stage != 0: return
        academy_action_stage = 1
        if is_instance_valid(enemy):
            enemy.disabled = true
            enemy.text = "ENEMY GUARD\nDEFEATED ✓"
        if is_instance_valid(ally):
            ally.text = "COURAGE ROOKIE\n3/1 • Ready"
        academy_feedback_text("Good trade. Your follower survived combat and may now attack the leader in this lesson.")
    , board)
    var leader: Button
    leader = button("ENEMY LEADER\n20 DEFENSE", Vector2(745,125), Vector2(210,118), func():
        if academy_action_stage == 0:
            academy_feedback_text("Guard's still standing. Clear your path before you go for the leader.", false)
            return
        if academy_action_stage != 1: return
        academy_action_stage = 2
        if is_instance_valid(leader):
            leader.text = "ENEMY LEADER\n17 DEFENSE"
        if is_instance_valid(ally):
            ally.disabled = true
        academy_feedback_text("Direct hit! The enemy leader lost 3 defense.")
        await get_tree().create_timer(0.8).timeout
        lesson_complete()
    , board)
    centered_label("1. Click ENEMY GUARD   2. Click ENEMY LEADER", Vector2(260,405), Vector2(570,38), 18, board)

func build_end_turn_lesson(board: Control) -> void:
    # A real two-phase simulation of the End Turn button instead of a wall of
    # rules text: clicking it shows the opponent's turn happening, then your
    # next turn actually reflects the PP-cap increase, the draw, and
    # followers readying -- the same three things start_player_turn() does
    # for real in main.gd.
    var status := centered_label(
        "YOUR TURN 2\nPlay Points: 1 / 3 remaining\nHand: 4 cards\nYour follower: TAPPED (already attacked)",
        Vector2(60, 130), Vector2(500, 110), 18, board)
    status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

    var upkeep_note := centered_label(
        "Anything with an end-of-turn effect (a Sponsor, or an Amulet like Daily Progress) also resolves the moment you end your turn.",
        Vector2(610, 130), Vector2(430, 90), 14, board)
    upkeep_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    upkeep_note.add_theme_color_override("font_color", Color(0.80,0.88,1.0))

    # Both buttons are looked up through this shared dict instead of being
    # closed over directly. GDScript func() literals snapshot outer locals by
    # VALUE at the moment they're created, not by reference -- so the END TURN
    # button's own closure (created first) would otherwise capture `continue_btn`
    # while it was still null (assigned only after this button() call returns),
    # and even its own `end_turn_btn` reference would be a stale null snapshot.
    # That silently broke both is_instance_valid checks below: the CONTINUE
    # button never actually became visible and END TURN never actually hid,
    # soft-locking the whole lesson (and the tutorial) on this screen forever.
    var controls := {"end_turn": null, "continue": null}

    controls["end_turn"] = button("END TURN", Vector2(430, 260), Vector2(230, 62), func():
        if academy_action_stage != 0: return
        academy_action_stage = 1
        var end_turn_btn = controls.get("end_turn")
        if is_instance_valid(end_turn_btn):
            end_turn_btn.disabled = true
            end_turn_btn.text = "ENDING TURN..."
        safe_set_text(status, "YOUR TURN 2 — ENDED\nOpponent's turn is happening now...")
        academy_feedback_text("Your turn is over. The opponent now plays their turn before control returns to you.")
        await get_tree().create_timer(1.0).timeout
        safe_set_text(status,
            "YOUR TURN 3\nPlay Points: 4 / 4 (max PP went up!)\nHand: 5 cards (you drew 1)\nYour follower: READY — can attack again")
        academy_feedback_text("Every End Turn: your max PP rises (until it caps), you draw a card, and all your followers ready. Click CONTINUE.")
        end_turn_btn = controls.get("end_turn")
        if is_instance_valid(end_turn_btn):
            end_turn_btn.visible = false
        var continue_btn = controls.get("continue")
        if is_instance_valid(continue_btn):
            continue_btn.visible = true
    , board)

    controls["continue"] = button("CONTINUE", Vector2(430, 260), Vector2(230, 62), func():
        if academy_action_stage != 1: return
        lesson_complete()
    , board)
    controls["continue"].visible = false

func build_signature_lesson(board: Control) -> void:
    # Every leader's Signature Platinum card is the closest thing this game
    # has to a "leader's special card" -- an evolve-for-free finisher that
    # defines their whole strategy. Purpose's true Amulet is taught
    # separately (Spells & Amulets lesson) since it's a different card type.
    var revealed: Dictionary = {}
    var controls := {"confirm": null}
    for i in range(CLASSES.size()):
        var c: String = CLASSES[i]
        var cd := card_by_id(str(LEADER_SIGNATURE_CARD_IDS.get(c, "")))
        if cd.is_empty():
            continue
        var wrap := VBoxContainer.new()
        wrap.position = Vector2(35 + i * 260, 20)
        wrap.custom_minimum_size = Vector2(240, 430)
        wrap.add_theme_constant_override("separation", 6)
        board.add_child(wrap)
        var title := centered_label(c.to_upper(), Vector2(0,0), Vector2(240,26), 16, wrap)
        title.add_theme_color_override("font_color", class_color(c))
        var cp := card_panel(cd, Vector2.ZERO, Vector2(200, 280), false)
        var cp_holder := CenterContainer.new(); cp_holder.custom_minimum_size = Vector2(240, 280)
        wrap.add_child(cp_holder); cp_holder.add_child(cp)
        var hint := centered_label("Tap to reveal", Vector2(0,0), Vector2(240,24), 12, wrap)
        hint.add_theme_color_override("font_color", Color(0.75,0.80,0.90))

        var tap_catcher := Button.new()
        tap_catcher.flat = true
        tap_catcher.focus_mode = Control.FOCUS_NONE
        tap_catcher.position = Vector2.ZERO
        tap_catcher.size = Vector2(200, 280)
        tap_catcher.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
        cp.add_child(tap_catcher)
        tap_catcher.pressed.connect(func():
            show_card_preview(cd)
            if revealed.has(c):
                return
            revealed[c] = true
            safe_set_text(hint, "Revealed ✓")
            academy_feedback_text("%d of 4 signature cards revealed." % revealed.size())
            var confirm_button = controls.get("confirm")
            if revealed.size() == CLASSES.size() and is_instance_valid(confirm_button):
                confirm_button.disabled = false
        )

    var continue_button := button("CONTINUE", Vector2(455, 505), Vector2(200, 50), func():
        var confirm_button = controls.get("confirm")
        if is_instance_valid(confirm_button) and confirm_button.disabled: return
        lesson_complete()
    , board)
    continue_button.disabled = true
    controls["confirm"] = continue_button

func build_keyword_lesson(board: Control) -> void:
    # A real card teaches each keyword instead of a glossary -- tapping opens
    # the same show_card_preview popup used everywhere else in the app, so
    # the lesson doubles as practice using the inspector players will rely
    # on during real matches.
    var revealed: Dictionary = {}
    var controls := {"confirm": null}
    var cols := 4
    for i in range(KEYWORD_EXAMPLE_CARDS.size()):
        var entry: Dictionary = KEYWORD_EXAMPLE_CARDS[i]
        var kw := str(entry.get("keyword", ""))
        var cd := card_by_id(str(entry.get("id", "")))
        if cd.is_empty():
            continue
        var col := i % cols
        var row := i / cols
        var wrap := VBoxContainer.new()
        wrap.position = Vector2(35 + col * 255, 15 + row * 250)
        wrap.custom_minimum_size = Vector2(235, 240)
        wrap.add_theme_constant_override("separation", 4)
        board.add_child(wrap)
        var title := centered_label(kw.to_upper(), Vector2(0,0), Vector2(235,22), 15, wrap)
        title.add_theme_color_override("font_color", GOLD_COLOR)
        var cp := card_panel(cd, Vector2.ZERO, Vector2(150, 150), false)
        var cp_holder := CenterContainer.new(); cp_holder.custom_minimum_size = Vector2(235, 150)
        wrap.add_child(cp_holder); cp_holder.add_child(cp)
        var hint := centered_label("Tap card to reveal", Vector2(0,0), Vector2(235,20), 11, wrap)
        hint.add_theme_color_override("font_color", Color(0.75,0.80,0.90))

        var tap_catcher := Button.new()
        tap_catcher.flat = true
        tap_catcher.focus_mode = Control.FOCUS_NONE
        tap_catcher.position = Vector2.ZERO
        tap_catcher.size = Vector2(150, 150)
        tap_catcher.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
        cp.add_child(tap_catcher)
        tap_catcher.pressed.connect(func():
            show_card_preview(cd)
            if revealed.has(kw):
                return
            revealed[kw] = true
            safe_set_text(hint, str(entry.get("meaning", "")))
            academy_feedback_text("%s: %s (%d of %d keywords revealed)" % [kw, str(entry.get("meaning","")), revealed.size(), KEYWORD_EXAMPLE_CARDS.size()])
            var confirm_button = controls.get("confirm")
            if revealed.size() == KEYWORD_EXAMPLE_CARDS.size() and is_instance_valid(confirm_button):
                confirm_button.disabled = false
        )

    var continue_button := button("CONTINUE", Vector2(455, 510), Vector2(200, 50), func():
        var confirm_button = controls.get("confirm")
        if is_instance_valid(confirm_button) and confirm_button.disabled: return
        lesson_complete()
    , board)
    continue_button.disabled = true
    controls["confirm"] = continue_button

func build_spell_amulet_lesson(board: Control) -> void:
    var status := centered_label("Enemy follower: 4/4\nOngoing effects: none",Vector2(60,125),Vector2(280,44),14,board)
    var spell: Button
    spell = academy_card("DEEP BREATH", "Spell • Freeze enemy", Vector2(60,180), class_color("Serenity"), func():
        if academy_action_stage != 0: return
        academy_action_stage = 1
        if is_instance_valid(spell):
            spell.disabled = true
            spell.text = "DEEP BREATH\nCAST ✓"
        safe_set_text(status, "Enemy follower: 4/4\nFROZEN — cannot attack")
        academy_feedback_text("Spells resolve immediately and then leave play. Now play Purpose's real Amulet.")
    , board)

    # Amulets don't have Attack/Defense and can't be attacked or damaged —
    # the only card type that persists purely for its ongoing text. Using
    # the game's one actual Amulet (Daily Progress) instead of an invented
    # example teaches the real end-turn-with-0-PP payoff players will
    # actually see when they pilot Purpose. Everything for this column lives
    # inside one VBoxContainer so the card art, its label, and the Progress
    # counter always stack cleanly instead of risking overlap with the spell
    # column at fixed absolute coordinates.
    var daily_progress := card_by_id("JD-054")
    var amulet_wrap := VBoxContainer.new()
    amulet_wrap.position = Vector2(740, 125)
    amulet_wrap.custom_minimum_size = Vector2(190, 260)
    amulet_wrap.add_theme_constant_override("separation", 8)
    board.add_child(amulet_wrap)
    centered_label("PURPOSE'S REAL AMULET", Vector2(0,0), Vector2(190,22), 13, amulet_wrap).add_theme_color_override("font_color", GOLD_COLOR)
    if not daily_progress.is_empty():
        var amulet_cp := card_panel(daily_progress, Vector2.ZERO, Vector2(190, 190))
        amulet_wrap.add_child(amulet_cp)
    var progress_note := centered_label("Progress: 0 / 6", Vector2(0,0), Vector2(190,26), 16, amulet_wrap)
    progress_note.add_theme_color_override("font_color", Color(0.90,0.85,0.65))

    var progress := [0]
    var play_amulet: Button
    play_amulet = button("PLAY DAILY PROGRESS", Vector2(60, 320), Vector2(280, 56), func():
        if academy_action_stage != 1:
            academy_feedback_text("Deep Breath first, Amulet second. One step at a time.", false)
            return
        academy_action_stage = 2
        if is_instance_valid(play_amulet):
            play_amulet.disabled = true
            play_amulet.text = "DAILY PROGRESS\nON THE BOARD ✓"
        academy_feedback_text("It's in play. Now end a turn with 0 PP left to gain Progress.")
    , board)

    var end_turn_zero_pp: Button
    end_turn_zero_pp = button("END TURN WITH 0 PP LEFT", Vector2(360, 320), Vector2(300, 56), func():
        if academy_action_stage != 2:
            academy_feedback_text("Nothing's counting yet — get Daily Progress on the board first.", false)
            return
        progress[0] += 1
        safe_set_text(progress_note, "Progress: %d / 6" % progress[0])
        if progress[0] == 3:
            academy_feedback_text("3 Progress reached: +1 maximum PP and your current followers are empowered.")
        elif progress[0] >= 6:
            safe_set_text(progress_note, "Progress: 6 / 6 — TRANSFORMED")
            academy_feedback_text("6 Progress: Daily Progress transforms into A Life Rebuilt. Amulets keep paying off the longer they stay in play.")
            academy_action_stage = 3
            await get_tree().create_timer(0.9).timeout
            lesson_complete()
        else:
            academy_feedback_text("+1 Progress. Do this again — at 3 Progress it empowers your board, and at 6 it transforms.")
    , board)

func build_recovery_lesson(board: Control) -> void:
    var status := centered_label("BATTLEFIELD\nONE DAY AT A TIME • 2/2",Vector2(375,105),Vector2(340,100),20,board)
    var relapse: Button
    relapse = button("RELAPSE ZONE\n0 cards",Vector2(100,285),Vector2(220,95),func():
        if academy_action_stage != 0: return
        academy_action_stage = 1
        safe_set_text(relapse, "RELAPSE ZONE\n1 card")
        safe_set_text(status, "BATTLEFIELD\n(empty)")
        academy_feedback_text("The follower entered the Relapse Zone. Now use Second Chance.")
    ,board)
    var recover: Button
    recover = button("SECOND CHANCE\nRecover a follower",Vector2(435,285),Vector2(220,95),func():
        if academy_action_stage != 1:
            academy_feedback_text("Nothing to recover yet — send someone to the Relapse Zone first.", false)
            return
        academy_action_stage = 2
        safe_set_text(relapse, "RELAPSE ZONE\n0 cards")
        safe_set_text(status, "BATTLEFIELD\nONE DAY AT A TIME • 3/3")
        if is_instance_valid(recover):
            recover.disabled = true
        academy_feedback_text("Recovered followers can return stronger. Now test an overdraw.")
    ,board)
    var overdraw: Button
    overdraw = button("DRAW AT 10 / 10\nTest overdraw",Vector2(770,285),Vector2(220,95),func():
        if academy_action_stage != 2:
            academy_feedback_text("Not yet — bring your follower back first, then we'll test the overdraw.", false)
            return
        academy_action_stage = 3
        safe_set_text(overdraw, "REVIVED ✓\nCard moved to deck bottom")
        academy_feedback_text("A full hand never destroys the card. It is Revived to the bottom of the deck.")
        await get_tree().create_timer(0.9).timeout
        lesson_complete()
    ,board)

func build_sponsor_lesson(board: Control) -> void:
    var sponsor: Button
    sponsor = academy_card("THE SPONSOR", "Signature Platinum", Vector2(120,275), GOLD_COLOR, func():
        if academy_action_stage != 0: return
        academy_action_stage = 1
        safe_set_text(sponsor, "THE SPONSOR\nIN PLAY ✓")
        academy_feedback_text("Sponsor entered play. Choose another allied follower as the Sponsee.")
    ,board)
    var sponsee: Button
    sponsee = academy_card("NEWCOMER", "Choose as Sponsee", Vector2(455,275), class_color("Hope"), func():
        if academy_action_stage != 1:
            academy_feedback_text("No Sponsor, no Sponsee. Play The Sponsor first.", false)
            return
        academy_action_stage = 2
        safe_set_text(sponsee, "SPONSEE\n4/4 • BONDED ✓")
        academy_feedback_text("The bond is active. Trigger protection to save the Sponsee from destruction.")
    ,board)
    var protect: Button
    protect = button("ENEMY STRIKE\nDeal lethal damage",Vector2(790,285),Vector2(220,95),func():
        if academy_action_stage != 2:
            academy_feedback_text("Pick your Sponsee before the hit lands.", false)
            return
        academy_action_stage = 3
        safe_set_text(protect, "PROTECTED ✓\nSponsee survives at 1")
        safe_set_text(sponsee, "SPONSEE\n4/1 • PROTECTED")
        academy_feedback_text("The Sponsor protected its Sponsee. Build-around cards make this bond even stronger.")
        await get_tree().create_timer(1.0).timeout
        lesson_complete()
    ,board)

func build_deck_building_lesson(board: Control) -> void:
    var copy_rules := centered_label(
        "A legal deck is EXACTLY 40 CARDS.\nUse only cards from your class plus Universal (Neutral) cards.",
        Vector2(60, 30), Vector2(970, 60), 20, board)
    copy_rules.add_theme_color_override("font_color", Color(0.96, 0.93, 0.82))

    var limits := ["BRONZE / SILVER / GOLD / EPIC\nup to 3 copies", "LEGENDARY\nup to 2 copies", "PLATINUM / SIGNATURE\nonly 1 copy"]
    var limit_colors := [Color(0.75, 0.75, 0.78), Color(0.55, 0.75, 1.0), GOLD_COLOR]
    for i in range(limits.size()):
        var chip := Panel.new()
        chip.position = Vector2(60 + i * 330, 110)
        chip.size = Vector2(300, 90)
        chip.add_theme_stylebox_override("panel", style(limit_colors[i], 12))
        board.add_child(chip)
        centered_label(limits[i], Vector2(10, 8), Vector2(280, 74), 16, chip)

    var acquire := centered_label(
        "GET NEW CARDS: open Packs from the Store, or CRAFT any card you're missing using Vials (Dust) earned from duplicates.",
        Vector2(80, 225), Vector2(890, 50), 17, board)
    acquire.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    acquire.add_theme_color_override("font_color", Color(0.80, 0.88, 1.0))

    var checklist := {"count": false, "limits": false, "craft": false}
    var controls := {"confirm": null}
    var make_check := func(text_value: String, pos: Vector2, key: String):
        var b: Button
        b = button(text_value, pos, Vector2(300, 56), func():
            if checklist[key]: return
            checklist[key] = true
            if is_instance_valid(b):
                b.disabled = true
                b.text += "  ✓"
            var done := 0
            for v in checklist.values():
                if v: done += 1
            academy_feedback_text("%d of 3 rules confirmed." % done)
            var confirm_button = controls.get("confirm")
            if done == 3 and is_instance_valid(confirm_button):
                confirm_button.disabled = false
        , board)
    make_check.call("CONFIRM: Deck = 40 cards", Vector2(60, 300), "count")
    make_check.call("CONFIRM: Class + Universal only", Vector2(390, 300), "limits")
    make_check.call("CONFIRM: Craft with Vials", Vector2(720, 300), "craft")

    var continue_button := button("OPEN THE DECK BUILDER LATER — CONTINUE", Vector2(300, 400), Vector2(480, 60), func():
        var confirm_button = controls.get("confirm")
        if is_instance_valid(confirm_button) and confirm_button.disabled: return
        lesson_complete()
    , board)
    continue_button.disabled = true
    controls["confirm"] = continue_button

func show_academy_graduation() -> void:
    clear_screen(); add_background(0.58)
    var p := Panel.new(); p.position=Vector2(220,72); p.size=Vector2(840,575); p.add_theme_stylebox_override("panel",style(GOLD_COLOR,22)); root_layer.add_child(p)
    var t := label("THE FIRST DAY COMPLETE",Vector2(40,42),Vector2(760,58),34,p); t.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; t.add_theme_color_override("font_color",GOLD_COLOR)
    label("You learned the foundations of WF Sober CCG.",Vector2(80,125),Vector2(680,50),21,p).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    # A short in-character send-off from the Dean closes out the Academy's
    # narrative through-line -- every lesson had a mentor voice, so the
    # capstone screen should too, instead of ending on plain reward copy.
    var dean_line := label("\"Eleven lessons in, and you already know more than you think you do. What you do with it next is up to you.\" — Dean Alvarez",Vector2(90,168),Vector2(660,50),14,p)
    dean_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    dean_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    dean_line.add_theme_color_override("font_color", GOLD_COLOR.lightened(0.35))
    label("YOUR REWARD\n\nChoose one legal 40-card starter deck\n500 Gold",Vector2(120,225),Vector2(600,150),27,p).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    if academy_complete:
        label("Training already completed — rewards can only be claimed once.",Vector2(130,390),Vector2(580,45),17,p).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
        button("RETURN HOME",Vector2(270,470),Vector2(300,58),show_home,p)
    else:
        button("CHOOSE YOUR STARTER DECK",Vector2(220,455),Vector2(400,64),show_graduation_class_choice,p)

    # Same soft entrance used for every lesson, so graduation reads as the
    # last beat of the same guided sequence rather than an abrupt jump-cut.
    root_layer.modulate.a = 0.0
    var grad_in := create_tween()
    grad_in.tween_property(root_layer, "modulate:a", 1.0, 0.32)

func show_graduation_class_choice() -> void:
    clear_screen(); add_background(0.70); header("CHOOSE YOUR PATH","Your reward is one exact 40-card starter deck and 500 Gold")
    for i in range(CLASSES.size()):
        var c: String = CLASSES[i]
        var panel := Panel.new(); panel.position=Vector2(42+i*310,154); panel.size=Vector2(286,430); panel.add_theme_stylebox_override("panel",style(class_color(c),16)); root_layer.add_child(panel)
        var art := TextureRect.new(); art.texture=class_leader_texture(c); art.position=Vector2(31,22); art.size=Vector2(224,224); art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED; art.clip_contents=true; panel.add_child(art)
        var n := label(c.to_upper(),Vector2(23,260),Vector2(240,38),25,panel); n.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; n.add_theme_color_override("font_color",class_color(c).lightened(0.25))
        label(class_description(c),Vector2(24,307),Vector2(238,58),15,panel).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
        button("CLAIM DECK",Vector2(48,374),Vector2(190,42),func(): graduate_with_class(c),panel)

func graduate_with_class(c: String) -> void:
    selected_class = c
    selected_deck_class = c
    grant_starter_collection(c)
    build_starter_deck(c)
    academy_complete = true
    academy_step = ACADEMY_LESSON_COUNT
    if not academy_reward_claimed:
        gold_balance += 500
        academy_reward_claimed = true
    save_profile()
    show_first_day_intro()

func start_developer_meta_battle(c: String) -> void:
    if not AccessManager.role_at_least(AccessManager.ROLE_OWNER):
        return
    launch_selected_battle(c, "meta")

func start_developer_final_boss_battle() -> void:
    if not AccessManager.role_at_least(AccessManager.ROLE_OWNER):
        return
    launch_selected_battle(selected_class if selected_class != "" else "Purpose", "final_boss")

func launch_selected_battle(c: String, deck_mode: String, opponent_class_value: String = "Courage", opponent_mode_value: String = "prebuilt", battle_mode: String = "ai") -> void:
    selected_class = c
    var cfg := ConfigFile.new()
    cfg.set_value("battle","mode",battle_mode)
    cfg.set_value("battle","your_class",c)
    cfg.set_value("battle","your_deck_mode",deck_mode)
    cfg.set_value("battle","opponent_class",opponent_class_value)
    # Computer opponents are always restricted to legal prebuilt decks.
    opponent_mode_value = "prebuilt"
    cfg.set_value("battle","opponent_deck_mode",opponent_mode_value)
    cfg.set_value("battle","developer_meta",deck_mode == "meta")
    cfg.save("user://battle_setup.cfg")
    await _show_battle_intro(c, opponent_class_value)


func _leader_first_name(cls: String) -> String:
    match cls:
        "Hope":     return "LYRA"
        "Courage":  return "KAEL"
        "Serenity": return "AURELIA"
        "Purpose":  return "ORIN"
    return cls.to_upper()

func _leader_title(cls: String) -> String:
    match cls:
        "Hope":     return "Dawn Returned"
        "Courage":  return "Flame Unbound"
        "Serenity": return "Voice of Calm"
        "Purpose":  return "Grand Architect"
    return ""

func _show_battle_intro(player_class_name: String, opponent_class_name: String) -> void:
    # Special cinematic for The Sponsor Trial.
    if opponent_class_name == "Sponsor":
        await _show_sponsor_cinematic()
        return

    var pc := class_color(player_class_name)
    var oc := class_color(opponent_class_name)

    # ── Root overlay ──────────────────────────────────────────────────────────
    var intro := ColorRect.new()
    intro.color = Color(0.004, 0.006, 0.014, 1.0)
    intro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    intro.z_index = 4096
    intro.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(intro)

    # ── Split background — each half tinted strongly to its class colour ──────
    var left_bg := ColorRect.new()
    left_bg.position = Vector2(0, 0); left_bg.size = Vector2(638, 720)
    left_bg.color = Color(pc.r * 0.13, pc.g * 0.13, pc.b * 0.17, 1.0)
    left_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    intro.add_child(left_bg)

    var right_bg := ColorRect.new()
    right_bg.position = Vector2(642, 0); right_bg.size = Vector2(638, 720)
    right_bg.color = Color(oc.r * 0.13, oc.g * 0.13, oc.b * 0.17, 1.0)
    right_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    intro.add_child(right_bg)

    # ── Full-height accent bars at top of each half ───────────────────────────
    var bar_l := ColorRect.new()
    bar_l.position = Vector2(0, 0); bar_l.size = Vector2(638, 6)
    bar_l.color = pc; bar_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    intro.add_child(bar_l)

    var bar_r := ColorRect.new()
    bar_r.position = Vector2(642, 0); bar_r.size = Vector2(638, 6)
    bar_r.color = oc; bar_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
    intro.add_child(bar_r)

    # ── Gold centre divider ───────────────────────────────────────────────────
    var divider := ColorRect.new()
    divider.position = Vector2(638, 0); divider.size = Vector2(4, 720)
    divider.color = Color(0.88, 0.72, 0.28, 0.60)
    divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
    intro.add_child(divider)

    # Portrait frame helper — returns a Panel with art inside, starts off-screen.
    # ── Left portrait — raw image, no frame, slides in from off-screen left ──
    var left_art := TextureRect.new()
    left_art.texture = class_leader_texture(player_class_name)
    left_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    left_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    left_art.position = Vector2(-700.0, 0.0)
    left_art.size = Vector2(660, 720)
    left_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
    left_art.modulate.a = 0.0
    intro.add_child(left_art)

    # Soft gradient fade on the right edge of the left portrait so it blends
    # naturally into the dark centre rather than hard-cutting.
    var left_fade := ColorRect.new()
    left_fade.position = Vector2(0, 0); left_fade.size = Vector2(660, 720)
    left_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    # Rendered as invisible — Godot ColorRect can't do horizontal gradients
    # natively; the portrait STRETCH_KEEP_ASPECT_COVERED already provides a
    # natural edge. Keep the node so the position reference is stable.
    left_fade.color = Color(0, 0, 0, 0)
    intro.add_child(left_fade)

    # ── Right portrait — raw image, no frame, slides in from off-screen right ─
    var right_art := TextureRect.new()
    right_art.texture = class_leader_texture(opponent_class_name)
    right_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    right_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    right_art.flip_h = true   # mirror so they face each other
    right_art.position = Vector2(1400.0, 0.0)
    right_art.size = Vector2(660, 720)
    right_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
    right_art.modulate.a = 0.0
    intro.add_child(right_art)

    # ── Leader name + title — bottom-third overlay on each side ──────────────
    # Left name plate
    var lp_name := Label.new()
    lp_name.text = _leader_first_name(player_class_name)
    lp_name.position = Vector2(20, 560); lp_name.size = Vector2(620, 50)
    lp_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    lp_name.add_theme_font_size_override("font_size", ui_font_size(42))
    lp_name.add_theme_color_override("font_color", pc.lightened(0.40))
    lp_name.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
    lp_name.add_theme_constant_override("shadow_offset_x", 2)
    lp_name.add_theme_constant_override("shadow_offset_y", 2)
    lp_name.modulate.a = 0.0
    intro.add_child(lp_name)

    var lp_title := Label.new()
    lp_title.text = _leader_title(player_class_name)
    lp_title.position = Vector2(20, 612); lp_title.size = Vector2(620, 30)
    lp_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    lp_title.add_theme_font_size_override("font_size", ui_font_size(20))
    lp_title.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.80))
    lp_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
    lp_title.add_theme_constant_override("shadow_offset_x", 1)
    lp_title.add_theme_constant_override("shadow_offset_y", 1)
    lp_title.modulate.a = 0.0
    intro.add_child(lp_title)

    # Right name plate (right-aligned, mirrored side)
    var rp_name := Label.new()
    rp_name.text = _leader_first_name(opponent_class_name)
    rp_name.position = Vector2(640, 560); rp_name.size = Vector2(620, 50)
    rp_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    rp_name.add_theme_font_size_override("font_size", ui_font_size(42))
    rp_name.add_theme_color_override("font_color", oc.lightened(0.40))
    rp_name.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
    rp_name.add_theme_constant_override("shadow_offset_x", 2)
    rp_name.add_theme_constant_override("shadow_offset_y", 2)
    rp_name.modulate.a = 0.0
    intro.add_child(rp_name)

    var rp_title := Label.new()
    rp_title.text = _leader_title(opponent_class_name)
    rp_title.position = Vector2(640, 612); rp_title.size = Vector2(620, 30)
    rp_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    rp_title.add_theme_font_size_override("font_size", ui_font_size(20))
    rp_title.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.80))
    rp_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
    rp_title.add_theme_constant_override("shadow_offset_x", 1)
    rp_title.add_theme_constant_override("shadow_offset_y", 1)
    rp_title.modulate.a = 0.0
    intro.add_child(rp_title)

    # ── VS label — dead centre ────────────────────────────────────────────────
    var vs := Label.new()
    vs.text = "VS"
    vs.position = Vector2(490, 290); vs.size = Vector2(300, 120)
    vs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vs.add_theme_font_size_override("font_size", ui_font_size(96))
    vs.add_theme_color_override("font_color", GOLD_COLOR)
    vs.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
    vs.add_theme_constant_override("shadow_offset_x", 3)
    vs.add_theme_constant_override("shadow_offset_y", 3)
    vs.scale = Vector2(0.10, 0.10)
    vs.pivot_offset = vs.size * 0.5
    vs.modulate.a = 0.0
    intro.add_child(vs)

    # ── Animation ─────────────────────────────────────────────────────────────
    var tween := create_tween().set_parallel(true)
    tween.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
    tween.tween_property(left_art,  "position:x", 0.0,    0.40)
    tween.tween_property(left_art,  "modulate:a", 1.0,    0.28)
    tween.tween_property(right_art, "position:x", 620.0,  0.40)
    tween.tween_property(right_art, "modulate:a", 1.0,    0.28)
    tween.tween_property(vs, "scale",      Vector2.ONE, 0.50)
    tween.tween_property(vs, "modulate:a", 1.0,         0.32)
    tween.tween_property(lp_name,  "modulate:a", 1.0, 0.30).set_delay(0.25)
    tween.tween_property(lp_title, "modulate:a", 1.0, 0.30).set_delay(0.33)
    tween.tween_property(rp_name,  "modulate:a", 1.0, 0.30).set_delay(0.25)
    tween.tween_property(rp_title, "modulate:a", 1.0, 0.30).set_delay(0.33)
    await get_tree().create_timer(0.45).timeout   # guard — tween.finished can hang

    await get_tree().create_timer(1.20).timeout
    AudioManager.stop_music(0.55)
    var fade := create_tween()
    fade.tween_property(intro, "modulate:a", 0.0, 0.50)
    await get_tree().create_timer(0.52).timeout   # guard — fade.finished can hang
    get_tree().change_scene_to_file("res://battle.tscn")

func _show_sponsor_cinematic() -> void:
    var intro := ColorRect.new()
    intro.color = Color(0.0, 0.0, 0.0, 1.0)
    intro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    intro.z_index = 4096
    intro.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(intro)

    var watch_label := Label.new()
    watch_label.text = "Someone has been watching your progress..."
    watch_label.position = Vector2(160, 230)
    watch_label.size = Vector2(960, 56)
    watch_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    watch_label.add_theme_font_size_override("font_size", ui_font_size(24))
    watch_label.add_theme_color_override("font_color", Color(0.82, 0.82, 0.82))
    watch_label.modulate.a = 0.0
    intro.add_child(watch_label)

    var t1 := create_tween()
    t1.tween_property(watch_label, "modulate:a", 1.0, 0.9)
    await t1.finished
    await get_tree().create_timer(1.3).timeout

    var glow := ColorRect.new()
    glow.color = Color(0.9, 0.72, 0.20, 0.0)
    glow.position = Vector2(400, 120)
    glow.size = Vector2(480, 480)
    intro.add_child(glow)

    var sponsor_art := TextureRect.new()
    sponsor_art.texture = load("res://assets/cards/full/jd-080.jpg")
    sponsor_art.position = Vector2(420, 132)
    sponsor_art.size = Vector2(440, 440)
    sponsor_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    sponsor_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    sponsor_art.clip_contents = true
    sponsor_art.modulate.a = 0.0
    intro.add_child(sponsor_art)

    var t2 := create_tween().set_parallel(true)
    t2.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    t2.tween_property(sponsor_art, "modulate:a", 1.0, 0.75)
    t2.tween_property(glow, "modulate:a", 0.22, 0.75)
    t2.tween_property(watch_label, "modulate:a", 0.0, 0.45)
    await t2.finished
    await get_tree().create_timer(0.4).timeout

    var name_label := Label.new()
    name_label.text = "THE SPONSOR"
    name_label.position = Vector2(160, 585)
    name_label.size = Vector2(960, 52)
    name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    name_label.add_theme_font_size_override("font_size", ui_font_size(38))
    name_label.add_theme_color_override("font_color", GOLD_COLOR)
    name_label.modulate.a = 0.0
    intro.add_child(name_label)

    var quote_label := Label.new()
    quote_label.text = "\"Recovery isn't about walking faster. It's about never walking alone.\""
    quote_label.position = Vector2(140, 648)
    quote_label.size = Vector2(1000, 72)
    quote_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    quote_label.add_theme_font_size_override("font_size", ui_font_size(19))
    quote_label.add_theme_color_override("font_color", Color(0.88, 0.88, 0.88))
    quote_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    quote_label.modulate.a = 0.0
    intro.add_child(quote_label)

    var t3 := create_tween().set_parallel(true)
    t3.tween_property(name_label, "modulate:a", 1.0, 0.6)
    t3.tween_property(quote_label, "modulate:a", 1.0, 0.9)
    await t3.finished
    await get_tree().create_timer(2.2).timeout

    AudioManager.stop_music(0.55)
    var fade := create_tween()
    fade.tween_property(intro, "modulate:a", 0.0, 0.65)
    await fade.finished
    intro.queue_free()
    get_tree().change_scene_to_file("res://battle.tscn")

func _battle_selection_set_class(class_name_value: String) -> void:
    battle_select_class = class_name_value
    show_match_deck_selection()

func _battle_selection_set_opponent_class(class_name_value: String) -> void:
    battle_opponent_class = class_name_value
    show_match_deck_selection()

func _battle_selection_set_mode(mode_value: String) -> void:
    battle_select_mode = mode_value
    show_match_deck_selection()

func _battle_selection_set_opponent_mode(_mode_value: String) -> void:
    battle_opponent_mode = "prebuilt"
    show_match_deck_selection()

func _battle_selection_start() -> void:
    battle_opponent_mode = "prebuilt"
    launch_selected_battle(battle_select_class, battle_select_mode, battle_opponent_class, "prebuilt")

func _battle_selection_start_practice() -> void:
    # Practice: your own deck vs. a legal AI deck, with a much longer turn
    # clock and no gold/challenge/trial payouts -- just a low-pressure place
    # to try a build and read cards.
    battle_opponent_mode = "prebuilt"
    launch_selected_battle(battle_select_class, battle_select_mode, battle_opponent_class, "prebuilt", "practice")

func _battle_preview_deck_ids(class_name_value: String, mode_value: String) -> Array:
    if mode_value == "custom":
        var current: Array = Array(saved_decks.get(class_name_value, []))
        if not current.is_empty():
            return current.duplicate()
    if mode_value == "meta":
        var meta_recipe: Dictionary = {}
        match class_name_value:
            "Courage":
                meta_recipe = {
                    "JD-030":1, "JD-016":3, "JD-017":3, "JD-018":3,
                    "JD-020":3, "JD-021":3, "JD-022":3, "JD-025":3,
                    "JD-026":2, "JD-029":2, "JD-089":3, "JD-090":3,
                    "JD-091":3, "JD-092":2
                }
            "Hope":
                meta_recipe = {
                    "JD-015":1, "JD-121":3, "JD-131":3, "JD-001":3, "JD-002":3,
                    "JD-003":3, "JD-005":3, "JD-006":3, "JD-007":3,
                    "JD-009":3, "JD-011":2, "JD-013":2, "JD-081":3,
                    "JD-082":3, "JD-083":2
                }
            "Serenity":
                meta_recipe = {
                    "JD-045":1, "JD-123":3, "JD-031":3, "JD-032":3,
                    "JD-033":3, "JD-034":3, "JD-035":3, "JD-036":3,
                    "JD-038":3, "JD-039":3, "JD-040":3, "JD-042":2,
                    "JD-043":2, "JD-098":2
                }
            "Purpose":
                meta_recipe = {
                    "JD-060":1, "JD-080":1, "JD-122":3, "JD-078":3,
                    "JD-061":3, "JD-046":3, "JD-047":3, "JD-048":3,
                    "JD-051":3, "JD-054":3, "JD-110":3, "JD-114":3,
                    "JD-117":3, "JD-119":2
                }
        return _recipe_to_exact_40(meta_recipe)
    if mode_value == "final_boss":
        # Cohesive benchmark deck: Purpose Progress + Sponsor/Sponsee engine.
        var boss_recipe := {
            "JD-046":3, "JD-047":3, "JD-048":3, "JD-049":3,
            "JD-051":3, "JD-054":3, "JD-057":2, "JD-060":1,
            "JD-061":3, "JD-078":3, "JD-080":1, "JD-110":2,
            "JD-114":3, "JD-117":2, "JD-119":2, "JD-077":2
        }
        return _recipe_to_exact_40(boss_recipe)
    var recipe: Dictionary = starter_recipe(class_name_value)
    var result: Array = []
    for card_id in recipe.keys():
        for _copy_index in range(int(recipe[card_id])):
            result.append(str(card_id))
    return result

func _recipe_to_exact_40(recipe: Dictionary) -> Array:
    var result: Array = []
    for card_id in recipe.keys():
        for _i in range(int(recipe[card_id])):
            if result.size() < 40:
                result.append(str(card_id))
    # Fill remaining slots with legal low-cost neutral consistency cards.
    var fillers := ["JD-061", "JD-071", "JD-072", "JD-073"]
    var fi := 0
    while result.size() < 40:
        result.append(fillers[fi % fillers.size()])
        fi += 1
    return result.slice(0, 40)

func _battle_preview_stats(class_name_value: String, mode_value: String) -> Dictionary:
    var ids: Array = _battle_preview_deck_ids(class_name_value, mode_value)
    var total_cost := 0
    var followers := 0
    var skills := 0
    var spells := 0
    var curve: Array = [0,0,0,0,0,0,0,0,0]
    for card_id_value in ids:
        var found: Dictionary = {}
        for card_data in cards:
            if str(card_data.get("id", "")) == str(card_id_value):
                found = Dictionary(card_data)
                break
        if found.is_empty():
            continue
        var cost_value := int(found.get("cost", 0))
        total_cost += cost_value
        curve[mini(cost_value, 8)] = int(curve[mini(cost_value, 8)]) + 1
        var type_text := str(found.get("type", "Follower")).to_lower()
        var effect_text := str(found.get("effect", "")).to_lower()
        if "amulet" in type_text or "recovery skill" in type_text or "recovery skill" in effect_text:
            skills += 1
        elif "spell" in type_text or (int(found.get("attack", 0)) == 0 and int(found.get("health", 0)) == 0):
            spells += 1
        else:
            followers += 1
    var count_value := maxi(ids.size(), 1)
    return {
        "count": ids.size(),
        "average": float(total_cost) / float(count_value),
        "followers": followers,
        "skills": skills,
        "spells": spells,
        "curve": curve
    }

func show_match_deck_selection() -> void:
    # ── Defaults ──────────────────────────────────────────────────────────────
    if battle_select_class == "":
        battle_select_class = selected_class if selected_class != "" else "Hope"
    if battle_opponent_class == "":
        battle_opponent_class = "Courage"
    if battle_select_mode in ["meta", "final_boss"] and not AccessManager.role_at_least(AccessManager.ROLE_OWNER):
        battle_select_mode = "custom"
    battle_opponent_mode = "prebuilt"
    if battle_select_mode == "custom" and last_battle_deck_idx < 0 and deck_slots.size() > 0:
        last_battle_deck_idx = 0
        battle_select_class = str(deck_slots[0].get("class", "Hope"))

    clear_screen()
    add_background(0.88)
    header("BATTLE PREPARATION", "Choose your champion and deck, then face your opponent.")

    # Shell height = 608 so bottom of screen (100+608=708) stays within 720.
    # This keeps both BEGIN BATTLE and PRACTICE MODE visible without scrolling.
    var shell := Panel.new()
    shell.position = Vector2(6, 100)
    shell.size = Vector2(1268, 608)
    shell.clip_contents = false
    shell.add_theme_stylebox_override("panel", style(Color(0.04, 0.06, 0.10), 0))
    root_layer.add_child(shell)

    # Left panel: all deck categories (MY DECKS / STARTER / OWNER)
    var left_p := Panel.new()
    left_p.position = Vector2(0, 0)
    left_p.size = Vector2(268, 608)
    left_p.add_theme_stylebox_override("panel", style(Color(0.05, 0.08, 0.14), 0))
    shell.add_child(left_p)
    _bp_build_deck_list(left_p)

    # Battle stage: cinematic MY LEADER vs OPPONENT display
    var stage := Panel.new()
    stage.position = Vector2(270, 0)
    stage.size = Vector2(998, 608)
    stage.clip_contents = true
    stage.add_theme_stylebox_override("panel", style(Color(0.04, 0.06, 0.10), 0))
    shell.add_child(stage)
    _bp_build_battle_stage(stage)


func _bp_get_selected_ids() -> Array:
    if last_battle_deck_idx >= 0 and last_battle_deck_idx < deck_slots.size():
        return Array(deck_slots[last_battle_deck_idx].get("cards", [])).duplicate()
    # meta, final_boss, and prebuilt all route through the existing helper
    return _battle_preview_deck_ids(battle_select_class, battle_select_mode if battle_select_mode in ["meta","final_boss","prebuilt"] else "prebuilt")

## Class for the currently-selected battle deck.
func _bp_get_selected_class() -> String:
    if last_battle_deck_idx >= 0 and last_battle_deck_idx < deck_slots.size():
        return str(deck_slots[last_battle_deck_idx].get("class", "Hope"))
    # For final_boss mode the class is fixed; for meta/prebuilt use battle_select_class
    if battle_select_mode == "final_boss":
        return selected_class if selected_class != "" else "Purpose"
    return battle_select_class

## Validates a deck slot. Returns "VALID" or a short reason string.
func _bp_slot_validation(slot: Dictionary) -> String:
    var slot_class := str(slot.get("class", ""))
    var cards_arr: Array = Array(slot.get("cards", []))
    if cards_arr.size() != 40:
        return "%d/40 cards" % cards_arr.size()
    var counts: Dictionary = {}
    for card_id in cards_arr:
        counts[str(card_id)] = int(counts.get(str(card_id), 0)) + 1
    for card_id in counts.keys():
        var cd := card_by_id(str(card_id))
        if cd.is_empty(): continue
        var limit := int(COPY_LIMITS.get(str(cd.get("rarity", "Bronze")), 3))
        if int(counts[str(card_id)]) > limit:
            return "Too many: %s" % str(cd.get("name", card_id))
        var cc := str(cd.get("class", ""))
        if cc != slot_class and cc != "Neutral":
            return "Wrong class: %s" % str(cd.get("name", card_id))
    return "VALID"

## Deck statistics computed directly from a card ID array.
func _bp_stats_from_ids(ids: Array) -> Dictionary:
    var total_cost := 0; var followers := 0; var skills := 0
    var curve: Array = [0,0,0,0,0,0,0,0,0]
    for card_id in ids:
        var cd := card_by_id(str(card_id))
        if cd.is_empty(): continue
        var cv := int(cd.get("cost", 0))
        total_cost += cv
        curve[mini(cv, 8)] = int(curve[mini(cv, 8)]) + 1
        var tt := str(cd.get("type", "")).to_lower()
        var eff := str(cd.get("effect", "")).to_lower()
        if "amulet" in tt or "recovery skill" in tt or "recovery skill" in eff:
            skills += 1
        elif not ("spell" in tt or (int(cd.get("attack", 0)) == 0 and int(cd.get("health", 0)) == 0)):
            followers += 1
    var n := maxi(ids.size(), 1)
    return {"count": ids.size(), "average": float(total_cost) / float(n),
            "followers": followers, "skills": skills, "curve": curve}

# ── Helpers: state changes ────────────────────────────────────────────────────

## Select a custom slot and refresh.
func _bp_select_slot(idx: int) -> void:
    last_battle_deck_idx = idx
    if idx >= 0 and idx < deck_slots.size():
        battle_select_class = str(deck_slots[idx].get("class", "Hope"))
    show_match_deck_selection()

## Select a prebuilt starter deck and refresh.
func _bp_select_prebuilt(cls: String) -> void:
    last_battle_deck_idx = -1
    battle_select_class = cls
    show_match_deck_selection()

## Launch the battle (or practice mode) using the selected deck.
func _bp_start_battle(practice: bool) -> void:
    # Owner-mode guard: meta and final_boss are developer-only
    if battle_select_mode in ["meta", "final_boss"] and not AccessManager.role_at_least(AccessManager.ROLE_OWNER):
        return
    var sel_class := _bp_get_selected_class()
    battle_select_class = sel_class
    if last_battle_deck_idx >= 0 and last_battle_deck_idx < deck_slots.size():
        var slot_cards: Array = Array(deck_slots[last_battle_deck_idx].get("cards", []))
        saved_decks[sel_class] = slot_cards.duplicate()
        selected_deck_class = sel_class
        saved_deck = slot_cards.duplicate()
        battle_select_mode = "custom"
    # meta and final_boss keep their mode as-is; prebuilt is default fallback
    elif battle_select_mode not in ["meta","final_boss"]:
        battle_select_mode = "prebuilt"
    if practice:
        launch_selected_battle(battle_select_class, battle_select_mode, battle_opponent_class, "prebuilt", "practice")
    else:
        launch_selected_battle(battle_select_class, battle_select_mode, battle_opponent_class, "prebuilt")

## Duplicate the selected custom slot.
func _bp_duplicate_slot() -> void:
    if last_battle_deck_idx < 0 or last_battle_deck_idx >= deck_slots.size():
        return
    if deck_slots.size() >= MAX_DECK_SLOTS:
        return
    var orig: Dictionary = Dictionary(deck_slots[last_battle_deck_idx])
    deck_slots.append({
        "name": str(orig.get("name", "Deck")) + " (Copy)",
        "class": str(orig.get("class", "Hope")),
        "cards": Array(orig.get("cards", [])).duplicate()
    })
    last_battle_deck_idx = deck_slots.size() - 1
    save_profile()
    show_match_deck_selection()

## Copy a prebuilt recipe into a new custom slot.
func _bp_copy_prebuilt(cls: String) -> void:
    if deck_slots.size() >= MAX_DECK_SLOTS:
        return
    var ids := _battle_preview_deck_ids(cls, "prebuilt")
    deck_slots.append({"name": cls + " Starter", "class": cls, "cards": ids.duplicate()})
    last_battle_deck_idx = deck_slots.size() - 1
    save_profile()
    show_match_deck_selection()

## Show a delete-confirmation overlay for the selected slot.
func _bp_confirm_delete() -> void:
    if last_battle_deck_idx < 0 or last_battle_deck_idx >= deck_slots.size():
        return
    var slot_name := str(deck_slots[last_battle_deck_idx].get("name", "Deck"))
    var overlay := ColorRect.new()
    overlay.color = Color(0, 0, 0, 0.72)
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.z_index = 400
    root_layer.add_child(overlay)
    var box := Panel.new()
    box.position = Vector2(390, 280)
    box.size = Vector2(500, 210)
    box.add_theme_stylebox_override("panel", style(Color(0.12, 0.18, 0.28), 16))
    overlay.add_child(box)
    centered_label("DELETE DECK?", Vector2(20, 18), Vector2(460, 36), 22, box).add_theme_color_override("font_color", GOLD_COLOR)
    var msg := centered_label("Delete \"%s\"? This cannot be undone." % slot_name,
        Vector2(20, 66), Vector2(460, 28), 15, box)
    msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    var cb := button("CANCEL", Vector2(30, 142), Vector2(196, 46),
        func(): overlay.queue_free(), box)
    cb.add_theme_stylebox_override("normal", style(Color(0.20, 0.30, 0.45), 10))
    var db := button("DELETE", Vector2(274, 142), Vector2(196, 46), func():
        overlay.queue_free()
        deck_slots.remove_at(last_battle_deck_idx)
        last_battle_deck_idx = mini(last_battle_deck_idx, deck_slots.size() - 1)
        save_profile()
        show_match_deck_selection()
    , box)
    db.add_theme_stylebox_override("normal", solid_style(Color(0.65, 0.22, 0.22), 10))
    db.add_theme_color_override("font_color", Color.WHITE)

## Show a rename overlay for the selected slot.
func _bp_rename_overlay() -> void:
    if last_battle_deck_idx < 0 or last_battle_deck_idx >= deck_slots.size():
        return
    var current_name := str(deck_slots[last_battle_deck_idx].get("name", "Deck"))
    var overlay := ColorRect.new()
    overlay.color = Color(0, 0, 0, 0.72)
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.z_index = 400
    root_layer.add_child(overlay)
    var box := Panel.new()
    box.position = Vector2(390, 270)
    box.size = Vector2(500, 220)
    box.add_theme_stylebox_override("panel", style(Color(0.12, 0.18, 0.28), 16))
    overlay.add_child(box)
    centered_label("RENAME DECK", Vector2(20, 18), Vector2(460, 36), 22, box).add_theme_color_override("font_color", GOLD_COLOR)
    var name_input := LineEdit.new()
    name_input.position = Vector2(30, 72)
    name_input.size = Vector2(440, 48)
    name_input.text = current_name
    name_input.select_all_on_focus = true
    name_input.add_theme_font_size_override("font_size", 20)
    box.add_child(name_input)
    name_input.grab_focus()
    var cb2 := button("CANCEL", Vector2(30, 150), Vector2(196, 46),
        func(): overlay.queue_free(), box)
    cb2.add_theme_stylebox_override("normal", style(Color(0.20, 0.30, 0.45), 10))
    var rb := button("RENAME", Vector2(274, 150), Vector2(196, 46), func():
        var new_name := name_input.text.strip_edges()
        if new_name == "": return
        deck_slots[last_battle_deck_idx]["name"] = new_name
        save_profile()
        overlay.queue_free()
        show_match_deck_selection()
    , box)
    rb.add_theme_stylebox_override("normal", solid_style(GOLD_COLOR, 10))
    rb.add_theme_color_override("font_color", Color(0.04, 0.06, 0.10))
    name_input.text_submitted.connect(func(_t: String): rb.pressed.emit())

## Open the deck builder to create a new slot.
func _bp_open_deck_builder_new() -> void:
    editing_deck_slot_idx = deck_slots.size()
    _show_create_slot_overlay()

## Open the deck builder to edit the selected slot.
func _bp_open_deck_builder_edit() -> void:
    if last_battle_deck_idx < 0 or last_battle_deck_idx >= deck_slots.size():
        return
    editing_deck_slot_idx = last_battle_deck_idx
    var slot: Dictionary = Dictionary(deck_slots[last_battle_deck_idx])
    selected_deck_class = str(slot.get("class", "Hope"))
    saved_deck = Array(slot.get("cards", [])).duplicate()
    saved_decks[selected_deck_class] = saved_deck.duplicate()
    show_deck_builder()

# ── Helpers: panel builders ───────────────────────────────────────────────────

## Section header label for the deck list scroll.
func _bp_section_hdr(text: String, vbox: VBoxContainer, col: Color) -> void:
    var lbl := Label.new()
    lbl.text = text
    lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    lbl.add_theme_font_size_override("font_size", ui_font_size(10))
    lbl.add_theme_color_override("font_color", col)
    lbl.custom_minimum_size = Vector2(292, 24)
    vbox.add_child(lbl)

## Adds a gold selection ring overlay to a Panel when is_sel is true.
func _bp_sel_ring(panel: Panel, is_sel: bool) -> void:
    if not is_sel: return
    var ring := Panel.new()
    ring.position = Vector2.ZERO
    var _rsz := panel.custom_minimum_size if panel.custom_minimum_size.x > 0.0 else panel.size
    ring.size = _rsz
    ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var rs := StyleBoxFlat.new()
    rs.bg_color = Color.TRANSPARENT
    rs.border_color = GOLD_COLOR; rs.set_border_width_all(2)
    rs.set_corner_radius_all(9)
    ring.add_theme_stylebox_override("panel", rs)
    panel.add_child(ring)

## Creates a transparent full-size tap Button child of parent.
func _bp_tap(sz: Vector2, parent: Control) -> Button:
    var b := Button.new(); b.flat = true
    b.focus_mode = Control.FOCUS_NONE
    b.position = Vector2.ZERO; b.size = sz
    b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    parent.add_child(b)
    return b

## Select a dev-only mode (meta / final_boss) and refresh.
func _bp_select_mode(mode: String, cls: String) -> void:
    if not AccessManager.role_at_least(AccessManager.ROLE_OWNER): return
    battle_select_mode = mode
    battle_select_class = cls
    last_battle_deck_idx = -1
    show_match_deck_selection()

func _bp_build_deck_list(parent: Panel) -> void:
    centered_label("SELECT DECK", Vector2(8, 10), Vector2(300, 26), 15, parent).add_theme_color_override("font_color", GOLD_COLOR)

    var scroll := ScrollContainer.new()
    scroll.position = Vector2(4, 42)
    scroll.size = Vector2(308, 592)
    scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    parent.add_child(scroll)

    var vbox := VBoxContainer.new()
    vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    vbox.add_theme_constant_override("separation", 5)
    scroll.add_child(vbox)

    # ─────── OWNER / DEVELOPER sections — shown first so no scrolling needed ──
    if AccessManager.role_at_least(AccessManager.ROLE_OWNER):
        _bp_section_hdr("OWNER  •  FINAL BOSS DECK", vbox, Color(1.0, 0.72, 0.20))

        var is_fb_sel: bool = (battle_select_mode == "final_boss")
        var fb := Panel.new()
        fb.custom_minimum_size = Vector2(292, 44)
        fb.add_theme_stylebox_override("panel", style(
            Color(0.52, 0.08, 0.08) if is_fb_sel else Color(0.12, 0.05, 0.05), 8))
        vbox.add_child(fb)

        label("The Sponsor — Final Boss", Vector2(11, 6), Vector2(270, 18), 13, fb)
        var fb_sub := label("ALL CLASSES  •  DEVELOPER ONLY", Vector2(11, 25), Vector2(270, 13), 9, fb)
        fb_sub.add_theme_color_override("font_color", Color(1.0, 0.72, 0.20))

        _bp_sel_ring(fb, is_fb_sel)

        var fbtap := _bp_tap(fb.custom_minimum_size, fb)
        fbtap.pressed.connect(func(): _bp_select_mode("final_boss", selected_class if selected_class != "" else "Purpose"))

        _bp_section_hdr("OWNER  •  DEV META DECKS", vbox, Color(1.0, 0.72, 0.20))

        for cls in CLASSES:
            var is_meta_sel: bool = (battle_select_mode == "meta" and battle_select_class == cls)
            var mb := Panel.new()
            mb.custom_minimum_size = Vector2(292, 44)
            mb.add_theme_stylebox_override("panel", style(
                class_color(cls).darkened(0.35) if is_meta_sel else Color(0.12, 0.09, 0.04), 8))
            vbox.add_child(mb)

            var mbbar := ColorRect.new()
            mbbar.color = class_color(cls); mbbar.position = Vector2(0, 0)
            mbbar.size = Vector2(4, 44); mbbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
            mb.add_child(mbbar)

            label(cls + " — Dev Meta", Vector2(11, 6), Vector2(210, 18), 12, mb)
            var m_sub := label("DEVELOPER ONLY", Vector2(11, 25), Vector2(210, 13), 9, mb)
            m_sub.add_theme_color_override("font_color", Color(1.0, 0.72, 0.20))

            _bp_sel_ring(mb, is_meta_sel)

            var mtap := _bp_tap(mb.custom_minimum_size, mb)
            var mcls: String = str(cls)
            mtap.pressed.connect(func(): _bp_select_mode("meta", mcls))

    # ─────────────────────────── PLAYER: MY DECKS ────────────────────────────
    _bp_section_hdr("PLAYER  •  MY DECKS", vbox, Color(0.55, 0.72, 0.95))

    if deck_slots.is_empty():
        var empty_lbl := Label.new()
        empty_lbl.text = "No custom decks yet.\nBuild one below or copy a starter."
        empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        empty_lbl.add_theme_font_size_override("font_size", ui_font_size(12))
        empty_lbl.add_theme_color_override("font_color", Color(0.50, 0.56, 0.68))
        empty_lbl.custom_minimum_size = Vector2(292, 50)
        vbox.add_child(empty_lbl)
    else:
        for i in range(deck_slots.size()):
            var slot: Dictionary = Dictionary(deck_slots[i])
            var slot_class := str(slot.get("class", ""))
            var slot_name  := str(slot.get("name",  "Deck %d" % (i + 1)))
            var slot_cards: Array = Array(slot.get("cards", []))
            var validation := _bp_slot_validation(slot)
            var valid      := validation == "VALID"
            var is_sel: bool = (last_battle_deck_idx == i and battle_select_mode == "custom")

            var entry := Panel.new()
            entry.custom_minimum_size = Vector2(292, 66)
            entry.add_theme_stylebox_override("panel", style(
                class_color(slot_class).darkened(0.48) if is_sel else Color(0.07, 0.11, 0.19), 9))
            vbox.add_child(entry)

            var cbar := ColorRect.new()
            cbar.color = class_color(slot_class)
            cbar.position = Vector2(0, 0); cbar.size = Vector2(4, 66)
            cbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
            entry.add_child(cbar)

            label(slot_name, Vector2(11, 7), Vector2(200, 20), 13, entry)
            var cls_lbl := label(slot_class.to_upper(), Vector2(11, 27), Vector2(130, 16), 10, entry)
            cls_lbl.add_theme_color_override("font_color", class_color(slot_class).lightened(0.38))

            var cc_col := Color(0.38, 0.78, 0.50) if slot_cards.size() == 40 else Color(0.85, 0.65, 0.30)
            centered_label("%d/40" % slot_cards.size(), Vector2(178, 6), Vector2(56, 18), 12, entry).add_theme_color_override("font_color", cc_col)
            var badge_col := Color(0.28, 0.72, 0.42) if valid else Color(0.82, 0.32, 0.32)
            centered_label("\u2713 VALID" if valid else "\u2717 INVALID", Vector2(178, 25), Vector2(106, 16), 10, entry).add_theme_color_override("font_color", badge_col)
            if not valid:
                var rl := label(validation, Vector2(11, 48), Vector2(268, 13), 9, entry)
                rl.add_theme_color_override("font_color", Color(0.80, 0.52, 0.52))
                rl.clip_text = true

            _bp_sel_ring(entry, is_sel)

            var ci := i
            var tap := _bp_tap(entry.custom_minimum_size, entry)
            tap.pressed.connect(func(): _bp_select_slot(ci))

    if deck_slots.size() < MAX_DECK_SLOTS:
        var nb := Button.new()
        nb.text = "+  CREATE NEW DECK"
        nb.custom_minimum_size = Vector2(292, 34)
        nb.add_theme_font_size_override("font_size", ui_font_size(11))
        nb.add_theme_stylebox_override("normal", style(Color(0.11, 0.18, 0.30), 8))
        nb.pressed.connect(_bp_open_deck_builder_new)
        vbox.add_child(nb)

    # ──────────────────────── STARTER: PREBUILT DECKS ────────────────────────
    _bp_section_hdr("STARTER  •  PREBUILT DECKS", vbox, Color(0.55, 0.72, 0.95))

    for cls in CLASSES:
        var is_pb_sel: bool = (last_battle_deck_idx == -1 and battle_select_class == cls and battle_select_mode == "prebuilt")
        var pb := Panel.new()
        pb.custom_minimum_size = Vector2(292, 48)
        pb.add_theme_stylebox_override("panel", style(
            class_color(cls).darkened(0.50) if is_pb_sel else Color(0.07, 0.11, 0.19), 8))
        vbox.add_child(pb)

        var pbbar := ColorRect.new()
        pbbar.color = class_color(cls); pbbar.position = Vector2(0, 0)
        pbbar.size = Vector2(4, 48); pbbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
        pb.add_child(pbbar)

        label(cls + " Starter", Vector2(11, 8), Vector2(185, 18), 13, pb)
        var sub_lbl := label("40 cards  \u2713  PREBUILT", Vector2(11, 28), Vector2(185, 14), 9, pb)
        sub_lbl.add_theme_color_override("font_color", Color(0.42, 0.78, 0.50))

        _bp_sel_ring(pb, is_pb_sel)

        # Left side: tap to select prebuilt
        var pbtap := _bp_tap(Vector2(230, 48), pb)
        var ccls: String = str(cls)
        pbtap.pressed.connect(func(): _bp_select_prebuilt(ccls))

        # Right side: COPY → creates a new custom slot
        if deck_slots.size() < MAX_DECK_SLOTS:
            var cpb := _bp_tap(Vector2(52, 48), pb)
            cpb.position = Vector2(236, 0)
            var ccls2: String = str(cls)
            cpb.pressed.connect(func(): _bp_copy_prebuilt(ccls2))
            var copy_lbl := centered_label("COPY\n\u2192", Vector2(236, 6), Vector2(52, 36), 9, pb)
            copy_lbl.add_theme_color_override("font_color", Color(0.65, 0.78, 1.0))
            copy_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE



func _bp_build_battle_stage(stage: Panel) -> void:
    var my_class  := _bp_get_selected_class()
    var opp_class: String = str(battle_opponent_class)
    var my_col    := class_color(my_class)
    var opp_col   := class_color(opp_class)

    # Dual tinted backgrounds — each leader's class color bleeds into their half.
    # The stage is 998 px wide; the VS strip is centered, so both leader zones
    # must be exactly (998 - 100) / 2 = 449 px wide.
    var bg_my := ColorRect.new()
    bg_my.color = Color(my_col.r * 0.12, my_col.g * 0.12, my_col.b * 0.18, 1.0)
    bg_my.position = Vector2.ZERO; bg_my.size = Vector2(449, 608)
    bg_my.mouse_filter = Control.MOUSE_FILTER_IGNORE
    stage.add_child(bg_my)

    var bg_vs := ColorRect.new()
    bg_vs.color = Color(0.02, 0.03, 0.06, 1.0)
    bg_vs.position = Vector2(449, 0); bg_vs.size = Vector2(100, 608)
    bg_vs.mouse_filter = Control.MOUSE_FILTER_IGNORE
    stage.add_child(bg_vs)

    var bg_opp := ColorRect.new()
    bg_opp.color = Color(opp_col.r * 0.12, opp_col.g * 0.12, opp_col.b * 0.18, 1.0)
    bg_opp.position = Vector2(549, 0); bg_opp.size = Vector2(449, 608)
    bg_opp.mouse_filter = Control.MOUSE_FILTER_IGNORE
    stage.add_child(bg_opp)

    _bp_build_my_leader_zone(stage, my_class, my_col)
    _bp_build_vs_zone(stage)
    _bp_build_opp_zone(stage, opp_class, opp_col)

    # ── Full-width BEGIN BATTLE bar at the bottom ─────────────────────────────
    var is_valid: bool = true
    if last_battle_deck_idx >= 0 and last_battle_deck_idx < deck_slots.size():
        is_valid = _bp_slot_validation(Dictionary(deck_slots[last_battle_deck_idx])) == "VALID"
    elif battle_select_mode not in ["meta", "final_boss", "prebuilt"]:
        is_valid = false

    var begin_b := button("\u2694  BEGIN BATTLE", Vector2(0, 480), Vector2(998, 62),
        func(): _bp_start_battle(false), stage)
    begin_b.add_theme_font_size_override("font_size", ui_font_size(22))
    if is_valid:
        begin_b.add_theme_stylebox_override("normal", solid_style(GOLD_COLOR, 0))
        begin_b.add_theme_color_override("font_color", Color(0.04, 0.06, 0.10))
    else:
        begin_b.add_theme_stylebox_override("normal", style(Color(0.22, 0.16, 0.08), 0))
        begin_b.add_theme_color_override("font_color", Color(0.50, 0.40, 0.28))
        begin_b.disabled = true

    var prac_b := button("PRACTICE MODE  \u2022  Long timer  \u2022  No ranked rewards",
        Vector2(0, 546), Vector2(998, 50), func(): _bp_start_battle(true), stage)
    prac_b.add_theme_font_size_override("font_size", ui_font_size(13))
    prac_b.add_theme_stylebox_override("normal", style(Color(0.12, 0.26, 0.16), 0))
    if not is_valid: prac_b.disabled = true

## MY LEADER zone — x=0, w=449
func _bp_build_my_leader_zone(parent: Control, my_class: String, my_col: Color) -> void:
    var PX := 8; var PY := 8; var PW := 433; var PH := 352

    # Outer zone glow (behind the framed portrait)
    var glow := ColorRect.new()
    glow.color = Color(my_col, 0.07)
    glow.position = Vector2(0, 0); glow.size = Vector2(449, PY + PH + 4)
    glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(glow)
    var gt := glow.create_tween().set_loops()
    gt.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    gt.tween_property(glow, "color:a", 0.18, 2.2)
    gt.tween_property(glow, "color:a", 0.03, 2.2)

    # Portrait frame
    var frame := Panel.new()
    frame.position = Vector2(PX, PY); frame.size = Vector2(PW, PH)
    frame.clip_contents = true
    var fs := StyleBoxFlat.new()
    fs.bg_color = Color(0.01, 0.015, 0.03)
    fs.set_corner_radius_all(10)
    fs.border_color = my_col; fs.set_border_width_all(2)
    frame.add_theme_stylebox_override("panel", fs)
    parent.add_child(frame)

    # LeaderView: layered animated portrait (blink, hair sway, aura pulse)
    var lv := _LeaderView.new()
    lv.setup(my_class, Vector2(PW, PH))
    lv.pivot_offset = Vector2(PW * 0.5, PH * 0.5)
    frame.add_child(lv)

    # Entrance scale animation on the whole view
    lv.scale = Vector2(0.96, 0.96)
    var at := lv.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    at.tween_property(lv, "scale", Vector2.ONE, 0.38)

    # Subtle class tint overlay (sits above LeaderView, below badges)
    var tint := ColorRect.new()
    tint.color = Color(my_col, 0.08)
    tint.position = Vector2.ZERO; tint.size = Vector2(PW, PH)
    tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
    frame.add_child(tint)

    # "MY LEADER" badge — top-left corner of portrait
    var badge := Panel.new()
    badge.position = Vector2(0, 0); badge.size = Vector2(138, 28)
    var bs := StyleBoxFlat.new(); bs.bg_color = Color(my_col.darkened(0.22), 0.92)
    bs.corner_radius_bottom_right = 8
    badge.add_theme_stylebox_override("panel", bs)
    frame.add_child(badge)
    centered_label("MY LEADER", Vector2(0, 0), Vector2(138, 28), 13, badge).add_theme_color_override("font_color", Color.WHITE)

    # Class name overlay at portrait bottom
    var grad := Panel.new()
    grad.position = Vector2(0, PH - 54); grad.size = Vector2(PW, 54)
    grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var gs := StyleBoxFlat.new(); gs.bg_color = Color(0.005, 0.01, 0.02, 0.90)
    grad.add_theme_stylebox_override("panel", gs)
    frame.add_child(grad)
    centered_label(my_class.to_upper(), Vector2(0, 6), Vector2(PW, 28), 22, grad).add_theme_color_override("font_color", my_col.lightened(0.35))

    # ── Below portrait: deck info + actions ───────────────────────────────────
    var ids := _bp_get_selected_ids()
    var is_custom: bool = (last_battle_deck_idx >= 0 and last_battle_deck_idx < deck_slots.size())
    var is_owner_mode: bool = (battle_select_mode in ["meta", "final_boss"])
    var slot_name := ""; var val_text := ""; var valid: bool = true

    if is_custom:
        var slot: Dictionary = Dictionary(deck_slots[last_battle_deck_idx])
        slot_name = str(slot.get("name", "Custom Deck"))
        val_text = _bp_slot_validation(slot); valid = (val_text == "VALID")
    elif is_owner_mode:
        slot_name = (my_class + " Dev Meta") if battle_select_mode == "meta" else "Sponsor \u2014 Final Boss"
        val_text = "DEVELOPER ONLY \u2014 ALWAYS VALID"; valid = true
    else:
        slot_name = my_class + " Starter Deck"
        val_text = "LEGAL PREBUILT \u2014 ALWAYS VALID"; valid = true

    var by := PY + PH + 8
    label(slot_name, Vector2(PX, by), Vector2(PW, 22), 15, parent)
    by += 25
    var vc := Color(0.28, 0.80, 0.44) if valid else Color(0.90, 0.28, 0.28)
    var vl := label(("\u2713  " if valid else "\u2717  ") + val_text, Vector2(PX, by), Vector2(PW, 18), 10, parent)
    vl.add_theme_color_override("font_color", vc)
    by += 22
    var st := _bp_stats_from_ids(ids)
    var sl := label("%d/40  \u2022  AVG %.1f  \u2022  %dF  \u2022  %dS" % [
        ids.size(), float(st.get("average", 0.0)), int(st.get("followers", 0)), int(st.get("skills", 0))],
        Vector2(PX, by), Vector2(PW, 14), 9, parent)
    sl.add_theme_color_override("font_color", Color(0.58, 0.70, 0.94))
    by += 20

    if is_custom:
        var ew := 88
        var eb := button("\u270F EDIT", Vector2(PX, by), Vector2(ew, 26), _bp_open_deck_builder_edit, parent)
        eb.add_theme_font_size_override("font_size", ui_font_size(10))
        eb.add_theme_stylebox_override("normal", style(Color(0.15, 0.24, 0.40), 6))
        var cb4 := button("\u2295 COPY", Vector2(PX + ew + 3, by), Vector2(ew, 26), _bp_duplicate_slot, parent)
        cb4.add_theme_font_size_override("font_size", ui_font_size(10))
        cb4.add_theme_stylebox_override("normal", style(Color(0.15, 0.24, 0.40), 6))
        if deck_slots.size() >= MAX_DECK_SLOTS: cb4.disabled = true
        var rb3 := button("\u270E NAME", Vector2(PX + (ew + 3) * 2, by), Vector2(ew, 26), _bp_rename_overlay, parent)
        rb3.add_theme_font_size_override("font_size", ui_font_size(10))
        rb3.add_theme_stylebox_override("normal", style(Color(0.15, 0.24, 0.40), 6))
        var dlb := button("\u2717 DEL", Vector2(PX + (ew + 3) * 3, by), Vector2(ew, 26), _bp_confirm_delete, parent)
        dlb.add_theme_font_size_override("font_size", ui_font_size(10))
        dlb.add_theme_stylebox_override("normal", style(Color(0.30, 0.10, 0.10), 6))

## VS divider strip — x=449, w=100
func _bp_build_vs_zone(parent: Control) -> void:
    var VX := 449; var VW := 100

    # Vertical gold lines flanking the VS text — centered in the 998 px stage
    var lt := ColorRect.new()
    lt.color = Color(GOLD_COLOR, 0.30)
    lt.position = Vector2(VX + VW / 2 - 1, 18); lt.size = Vector2(2, 148)
    lt.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(lt)

    centered_label("VS", Vector2(VX, 166), Vector2(VW, 100), 48, parent).add_theme_color_override("font_color", GOLD_COLOR)

    var lb := ColorRect.new()
    lb.color = Color(GOLD_COLOR, 0.30)
    lb.position = Vector2(VX + VW / 2 - 1, 266); lb.size = Vector2(2, 264)
    lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(lb)

    # Vertical separator between left deck panel and stage
    var left_sep := ColorRect.new()
    left_sep.color = Color(GOLD_COLOR, 0.12)
    left_sep.position = Vector2(0, 0); left_sep.size = Vector2(2, 534)
    left_sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(left_sep)

## OPPONENT zone — x=549, w=449
func _bp_build_opp_zone(parent: Control, opp_class: String, opp_col: Color) -> void:
    var OX := 549; var OW := 449
    var PX := OX + 8; var PY := 8; var PW := 433; var PH := 352

    # Pulsing aura (slightly offset phase from MY side for visual interest)
    var glow := ColorRect.new()
    glow.color = Color(opp_col, 0.07)
    glow.position = Vector2(OX, 0); glow.size = Vector2(OW, PY + PH + 4)
    glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(glow)
    var gt := glow.create_tween().set_loops()
    gt.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    gt.tween_property(glow, "color:a", 0.18, 2.6)
    gt.tween_property(glow, "color:a", 0.03, 2.6)

    # Portrait frame
    var frame := Panel.new()
    frame.position = Vector2(PX, PY); frame.size = Vector2(PW, PH)
    frame.clip_contents = true
    var fs := StyleBoxFlat.new()
    fs.bg_color = Color(0.01, 0.015, 0.03)
    fs.set_corner_radius_all(10)
    fs.border_color = opp_col; fs.set_border_width_all(2)
    frame.add_theme_stylebox_override("panel", fs)
    parent.add_child(frame)

    # LeaderView: layered animated portrait (blink, hair sway, aura pulse)
    var lv_opp := _LeaderView.new()
    lv_opp.setup(opp_class, Vector2(PW, PH))
    lv_opp.pivot_offset = Vector2(PW * 0.5, PH * 0.5)
    frame.add_child(lv_opp)

    # Entrance animation (slightly offset from MY side)
    lv_opp.scale = Vector2(0.96, 0.96)
    var at := lv_opp.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    at.tween_property(lv_opp, "scale", Vector2.ONE, 0.42)

    # Subtle class tint overlay
    var tint := ColorRect.new()
    tint.color = Color(opp_col, 0.08)
    tint.position = Vector2.ZERO; tint.size = Vector2(PW, PH)
    tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
    frame.add_child(tint)

    # "OPPONENT" badge — top-right of portrait
    var badge := Panel.new()
    badge.position = Vector2(PW - 138, 0); badge.size = Vector2(138, 28)
    var bds := StyleBoxFlat.new(); bds.bg_color = Color(opp_col.darkened(0.22), 0.92)
    bds.corner_radius_bottom_left = 8
    badge.add_theme_stylebox_override("panel", bds)
    frame.add_child(badge)
    centered_label("OPPONENT", Vector2(0, 0), Vector2(138, 28), 13, badge).add_theme_color_override("font_color", Color.WHITE)

    # Class name overlay at portrait bottom
    var grad := Panel.new()
    grad.position = Vector2(0, PH - 54); grad.size = Vector2(PW, 54)
    grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var gs := StyleBoxFlat.new(); gs.bg_color = Color(0.005, 0.01, 0.02, 0.90)
    grad.add_theme_stylebox_override("panel", gs)
    frame.add_child(grad)
    centered_label(opp_class.to_upper(), Vector2(0, 6), Vector2(PW, 28), 22, grad).add_theme_color_override("font_color", opp_col.lightened(0.35))

    # ── Below portrait: choose opponent ──────────────────────────────────────
    var by := PY + PH + 8
    centered_label("CHOOSE OPPONENT", Vector2(PX, by), Vector2(PW, 18), 11, parent).add_theme_color_override("font_color", Color(0.60, 0.72, 0.96))
    by += 24

    # 2x2 class selector grid
    var btn_w := int((PW - 8) / 2)
    for i in range(CLASSES.size()):
        var cls: String = str(CLASSES[i])
        var col := i % 2; var row := i / 2
        var bx := PX + col * (btn_w + 8)
        var btn_y := by + row * 40
        var ob := Panel.new()
        ob.position = Vector2(bx, btn_y); ob.size = Vector2(btn_w, 34)
        var is_osel: bool = (cls == opp_class)
        ob.add_theme_stylebox_override("panel", style(
            class_color(cls).darkened(0.22) if is_osel else Color(0.06, 0.09, 0.16), 8))
        parent.add_child(ob)
        _bp_sel_ring(ob, is_osel)
        centered_label(cls.to_upper(), Vector2(4, 0), Vector2(btn_w - 8, 34), 12, ob).add_theme_color_override(
            "font_color", class_color(cls).lightened(0.30) if is_osel else Color.WHITE)
        var otap := _bp_tap(ob.size, ob)
        var c_opp: String = cls
        otap.pressed.connect(func(): battle_opponent_class = c_opp; show_match_deck_selection())

    by += 82
    # Opponent deck info + preview button
    var opp_s := _battle_preview_stats(opp_class, "prebuilt")
    var oi := label("Prebuilt Deck  \u2022  40 cards  \u2022  AVG %.1f" % float(opp_s.get("average", 0.0)),
        Vector2(PX, by), Vector2(PW - 110, 14), 9, parent)
    oi.add_theme_color_override("font_color", Color(0.55, 0.65, 0.88))
    var c_cls: String = opp_class
    var prev_b := button("\ud83d\udd0d  VIEW DECK", Vector2(PX + PW - 106, by - 4), Vector2(106, 24),
        func(): _show_battle_deck_preview(c_cls, "prebuilt", true), parent)
    prev_b.add_theme_font_size_override("font_size", ui_font_size(10))
    prev_b.add_theme_stylebox_override("normal", style(Color(0.10, 0.18, 0.30), 6))
    prev_b.add_theme_stylebox_override("hover",  style(Color(0.18, 0.30, 0.50), 6))


func _show_battle_deck_preview(class_name_value: String, mode_value: String, opponent_preview: bool) -> void:
    if opponent_preview:
        mode_value = "prebuilt"
    clear_screen()
    add_background(0.82)
    var side_title := "OPPONENT DECK PREVIEW" if opponent_preview else "YOUR DECK PREVIEW"
    header(side_title, "%s • %s" % [class_name_value.to_upper(), ("LEGAL PREBUILT" if opponent_preview else mode_value.to_upper())])

    var panel := Panel.new()
    panel.position = Vector2(84, 106)
    panel.size = Vector2(1112, 560)
    panel.add_theme_stylebox_override("panel", style(class_color(class_name_value), 20))
    root_layer.add_child(panel)

    var ids: Array = _battle_preview_deck_ids(class_name_value, mode_value)
    var counts: Dictionary = {}
    for card_id_value in ids:
        counts[str(card_id_value)] = int(counts.get(str(card_id_value), 0)) + 1

    # Every prebuilt/custom deck preview is anchored by its dedicated leader art.
    var leader_frame := Panel.new()
    leader_frame.position = Vector2(24, 58)
    leader_frame.size = Vector2(246, 430)
    leader_frame.clip_contents = true
    leader_frame.add_theme_stylebox_override("panel", style(class_color(class_name_value).lightened(0.12), 14))
    panel.add_child(leader_frame)
    var leader_art := TextureRect.new()
    leader_art.texture = class_leader_texture(class_name_value)
    leader_art.position = Vector2(10, 10)
    leader_art.size = Vector2(226, 226)
    leader_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    leader_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    leader_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
    leader_frame.add_child(leader_art)
    centered_label(class_name_value.to_upper(), Vector2(10, 246), Vector2(226, 34), 22, leader_frame).add_theme_color_override("font_color", GOLD_COLOR)
    centered_label("DEDICATED LEADER", Vector2(10, 282), Vector2(226, 24), 12, leader_frame)
    var leader_desc := centered_label(class_description(class_name_value), Vector2(18, 314), Vector2(210, 70), 13, leader_frame)
    leader_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    leader_desc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    centered_label("ORIGINAL LEADER ART", Vector2(10, 392), Vector2(226, 24), 11, leader_frame).add_theme_color_override("font_color", Color(0.82,0.88,1.0))

    var scroll := ScrollContainer.new()
    scroll.position = Vector2(286, 58)
    scroll.size = Vector2(800, 430)
    panel.add_child(scroll)
    var list := VBoxContainer.new()
    list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    list.add_theme_constant_override("separation", 8)
    scroll.add_child(list)

    var rows: Array = []
    for card_id in counts.keys():
        var found: Dictionary = {}
        for card_data in cards:
            if str(card_data.get("id", "")) == str(card_id):
                found = Dictionary(card_data)
                break
        if found.is_empty():
            rows.append({"name": str(card_id), "cost": 0, "rarity": "", "count": int(counts[card_id]), "card": {}})
        else:
            rows.append({"name": str(found.get("name", card_id)), "cost": int(found.get("cost", 0)), "rarity": str(found.get("rarity", "")), "count": int(counts[card_id]), "card": found})
    rows.sort_custom(func(a: Dictionary, b: Dictionary):
        if int(a.get("cost", 0)) == int(b.get("cost", 0)):
            return str(a.get("name", "")) < str(b.get("name", ""))
        return int(a.get("cost", 0)) < int(b.get("cost", 0))
    )

    for row_data in rows:
        var row: Dictionary = Dictionary(row_data)
        var row_panel := Panel.new()
        row_panel.custom_minimum_size = Vector2(760, 42)
        row_panel.add_theme_stylebox_override("panel", style(Color(0.08,0.12,0.20,0.94), 9))
        list.add_child(row_panel)
        var cost_label := centered_label(str(row.get("cost", 0)), Vector2(8, 5), Vector2(42, 32), 18, row_panel)
        cost_label.add_theme_color_override("font_color", GOLD_COLOR)
        label("%dx  %s" % [int(row.get("count", 1)), str(row.get("name", "Card"))], Vector2(62, 7), Vector2(500, 28), 16, row_panel)
        var rarity_label := centered_label(str(row.get("rarity", "")), Vector2(566, 7), Vector2(140, 28), 13, row_panel)
        rarity_label.add_theme_color_override("font_color", Color(0.82,0.88,1.0))
        # Deck-preview rows only ever showed name/cost/rarity as flat text --
        # there was no way to check a card's actual stats or ability wording
        # before committing to a matchup. Reuse the same tap-to-inspect popup
        # the collection/deck-builder grids already have.
        var row_card: Dictionary = row.get("card", {})
        if not row_card.is_empty():
            var row_tap := Button.new()
            row_tap.flat = true
            row_tap.focus_mode = Control.FOCUS_NONE
            row_tap.position = Vector2.ZERO
            row_tap.size = row_panel.custom_minimum_size
            row_tap.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
            row_tap.tooltip_text = "Tap to inspect this card"
            row_tap.pressed.connect(show_card_preview.bind(row_card))
            row_panel.add_child(row_tap)

    centered_label("%d cards total" % ids.size(), Vector2(30, 500), Vector2(260, 34), 15, panel)
    button("BACK TO BATTLE SETUP", Vector2(790, 500), Vector2(290, 38), show_match_deck_selection, panel)

func _build_battle_leader_panel(class_name_value: String, heading: String, panel_position: Vector2, parent: Control, dim_art: bool) -> Panel:
    var panel := Panel.new()
    panel.position = panel_position
    panel.size = Vector2(328, 344)
    panel.clip_contents = true
    panel.add_theme_stylebox_override("panel", style(Color(0.025, 0.045, 0.075, 0.98), 16))
    parent.add_child(panel)
    centered_label(heading, Vector2(14, 8), Vector2(300, 26), 15, panel).add_theme_color_override("font_color", GOLD_COLOR)

    var frame := ColorRect.new()
    frame.position = Vector2(14, 40)
    frame.size = Vector2(300, 250)
    frame.color = Color(0.02, 0.03, 0.05, 1)
    frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
    frame.clip_contents = true
    panel.add_child(frame)

    var art := TextureRect.new()
    art.texture = class_leader_texture(class_name_value)
    art.position = Vector2(6, 6)
    art.size = Vector2(288, 238)
    art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    art.clip_contents = true
    art.mouse_filter = Control.MOUSE_FILTER_IGNORE
    if dim_art:
        art.modulate = Color(0.92, 0.94, 0.98)
    frame.add_child(art)

    var banner := Panel.new()
    banner.position = Vector2(14, 298)
    banner.size = Vector2(300, 34)
    banner.add_theme_stylebox_override("panel", style(Color(0.06,0.09,0.14,0.96), 8))
    panel.add_child(banner)
    centered_label(class_name_value.to_upper(), Vector2(4, 1), Vector2(292, 30), 20, banner).add_theme_color_override("font_color", Color.WHITE)
    return panel

func _draw_curve(parent: Control, curve: Array, origin: Vector2, curve_color: Color, width: float) -> void:
    centered_label("COST CURVE", origin + Vector2(0,-20), Vector2(width,20), 12, parent).add_theme_color_override("font_color", GOLD_COLOR)
    var safe_curve: Array = curve.duplicate()
    while safe_curve.size() < 9:
        safe_curve.append(0)
    var max_curve := 1
    for value in safe_curve:
        max_curve = maxi(max_curve, int(value))
    var step := width / 9.0
    for i in range(9):
        var bar_height := 58.0 * float(int(safe_curve[i])) / float(max_curve)
        var bar := ColorRect.new()
        bar.position = origin + Vector2(i * step + 4, 70 - bar_height)
        bar.size = Vector2(maxf(step - 8.0, 8.0), bar_height)
        bar.color = curve_color.lightened(0.15)
        parent.add_child(bar)
        var lbl := label("8+" if i == 8 else str(i), origin + Vector2(i * step, 74), Vector2(step,18), 9, parent)
        lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func start_battle() -> void:
    # Keep the recovery theme active throughout deck selection.
    ensure_home_music()
    show_match_deck_selection()

func show_class_choice() -> void:
    clear_screen()
    add_background(0.78)
    header("PREBUILT DECKS", "Choose a leader and inspect the complete legal 40-card deck before battle.")

    # Four equal hero deck panels. These intentionally mirror the home-screen
    # leader presentation instead of squeezing the art into old card frames.
    var grid := Control.new()
    grid.position = Vector2(24, 106)
    grid.size = Vector2(1232, 512)
    root_layer.add_child(grid)

    for i in range(CLASSES.size()):
        var c: String = CLASSES[i]
        var card := Panel.new()
        card.position = Vector2(i * 304, 0)
        card.size = Vector2(290, 500)
        card.clip_contents = true
        card.add_theme_stylebox_override("panel", style(Color(0.025, 0.045, 0.075, 0.98), 18))
        grid.add_child(card)

        # Dedicated clipped art viewport. Full leader composition is shown with
        # aspect-fit and can never spill into the deck information below it.
        var art_shell := Panel.new()
        art_shell.position = Vector2(10, 10)
        art_shell.size = Vector2(270, 278)
        art_shell.clip_contents = true
        art_shell.add_theme_stylebox_override("panel", style(class_color(c).darkened(0.58), 15))
        card.add_child(art_shell)

        var art := TextureRect.new()
        art.texture = class_leader_texture(c)
        art.position = Vector2(7, 7)
        art.size = Vector2(256, 264)
        art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
        art.clip_contents = true
        art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
        art.mouse_filter = Control.MOUSE_FILTER_IGNORE
        art_shell.add_child(art)

        var name_bar := Panel.new()
        name_bar.position = Vector2(10, 296)
        name_bar.size = Vector2(270, 48)
        name_bar.add_theme_stylebox_override("panel", style(Color(0.035, 0.055, 0.09, 0.98), 10))
        card.add_child(name_bar)
        var title := centered_label(c.to_upper(), Vector2(4, 3), Vector2(262, 40), 23, name_bar)
        title.add_theme_color_override("font_color", class_color(c).lightened(0.28))

        centered_label("PREBUILT • 40 CARDS", Vector2(10, 350), Vector2(270, 22), 12, card).add_theme_color_override("font_color", GOLD_COLOR)

        var desc := centered_label(class_description(c), Vector2(18, 376), Vector2(254, 48), 13, card)
        desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        desc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

        var stats: Dictionary = _battle_preview_stats(c, "prebuilt")
        var stat_text := "%d Followers  •  %d Skills
Avg Cost %.1f" % [int(stats.get("followers", 0)), int(stats.get("skills", 0)), float(stats.get("average", 0.0))]
        var stat_label := centered_label(stat_text, Vector2(16, 426), Vector2(258, 36), 11, card)
        stat_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

        var selected_class_value := c
        var select_btn := button("VIEW / SELECT", Vector2(22, 464), Vector2(246, 30), func(): choose_class(selected_class_value), card)
        select_btn.add_theme_stylebox_override("normal", style(class_color(c).darkened(0.25), 9))
        select_btn.add_theme_stylebox_override("hover", style(class_color(c).lightened(0.02), 9))
        select_btn.add_theme_font_size_override("font_size", ui_font_size(12))

    button("BACK HOME", Vector2(500, 630), Vector2(280, 42), show_home, root_layer)

func class_leader_texture(class_name_value: String) -> Texture2D:
    # The Sponsor has no /assets/leaders/ portrait — route straight to his card art.
    if class_name_value.to_lower() == "sponsor":
        return load("res://assets/cards/full/jd-080.jpg")
    # The source leader illustrations are square, full-scene paintings (podium,
    # backpack trail, lakeside, job site) with the character occupying the top
    # portion. Framed at full size with a "contain" stretch they read as tiny
    # figures lost in a big scene; cropped to the top ~60% and displayed with
    # a "cover" stretch, they read as a proper bust-style leader portrait in
    # every frame in the app, the same way regardless of that frame's shape.
    #
    # The source art also has its own thin painted picture-frame border baked
    # into every edge. Cropping straight to the top 60% keeps the side/top
    # borders but drops the bottom one, leaving a border that doesn't close —
    # a stray straight-edged line sitting inside the app's own rounded card
    # frame. Insetting past that painted border on all sides first removes it
    # entirely, so every leader card shows clean art with a single frame
    # (the app's own), not a broken one layered inside another.
    var base := load("res://assets/leaders/%s.png" % class_name_value.to_lower())
    if base == null:
        return null
    var margin: float = base.get_width() * 0.045
    var inset_w: float = base.get_width() - margin * 2.0
    var inset_h: float = base.get_height() - margin * 2.0
    var atlas := AtlasTexture.new()
    atlas.atlas = base
    atlas.region = Rect2(margin, margin, inset_w, inset_h * 0.72)
    return atlas

func current_leader_texture(class_name_value: String) -> Texture2D:
    # The Sponsor is a cosmetic leader-art swap won from The Trials: it
    # replaces the portrait shown for whichever class the player is actually
    # playing, but never changes what class/deck they're building or piloting.
    if selected_leader_skin == "sponsor" and sponsor_leader_unlocked:
        return load("res://assets/cards/full/jd-080.jpg")
    return class_leader_texture(class_name_value)

func toggle_sponsor_skin() -> void:
    selected_leader_skin = "" if selected_leader_skin == "sponsor" else "sponsor"
    save_profile()
    show_home()

func class_description(c: String) -> String:
    match c:
        "Hope": return "Healing, renewal, and card advantage"
        "Courage": return "Fast attacks and relentless pressure"
        "Serenity": return "Defense, control, and protection"
        _: return "Growth, planning, and powerful finishers"

func choose_class(c: String) -> void:
    selected_class = c; selected_deck_class = c
    grant_starter_collection(c)
    build_starter_deck(c)
    save_profile()
    if pending_after_class_choice.is_valid():
        var callback := pending_after_class_choice
        pending_after_class_choice = Callable()
        callback.call()
    else:
        show_home()

func grant_starter_collection(c: String) -> void:
    for card_data in cards:
        if str(card_data.get("id", "")) == "JD-080":
            continue
        if str(card_data["class"]) == c or str(card_data["class"]) == "Neutral":
            var id := str(card_data["id"])
            var limit := int(COPY_LIMITS.get(str(card_data["rarity"]),1))
            collection_owned[id] = maxi(int(collection_owned.get(id,0)), limit)

func starter_recipe(c: String) -> Dictionary:
    # v0.2.4: Every prebuilt deck is exactly 40 cards and is rebuilt to teach
    # its class resource. Cards below Legendary may use up to 3 copies,
    # Legendaries use up to 2, and the class Platinum remains a single copy.
    var recipes := {
        "Hope": {
            # Hope generators: healing, recovery, and Relapse Zone value.
            "JD-001":3, "JD-003":3, "JD-005":3, "JD-006":3, "JD-009":3,
            "JD-010":3, "JD-081":3, "JD-082":3,
            # Hope payoffs and finishers -- The Comeback Trail is Hope's class
            # amulet (its Relapse Zone recovery engine), the same role every
            # other class's starter deck gives its own amulet.
            "JD-007":3, "JD-012":2, "JD-015":1, "JD-131":3,
            # Neutral consistency package.
            "JD-061":3, "JD-071":2, "JD-072":2
        },
        "Courage": {
            # Resolve generators: combat, survival, and efficient trading.
            "JD-016":3, "JD-018":3, "JD-020":3, "JD-021":3, "JD-022":3,
            "JD-089":3, "JD-090":3, "JD-093":3,
            # Resolve spenders and board payoffs.
            "JD-024":3, "JD-025":3, "JD-029":2, "JD-030":1,
            # Neutral tempo package.
            "JD-061":3, "JD-071":2, "JD-073":2
        },
        "Serenity": {
            # Peace generators: patience, healing, and Recovery Skill play.
            "JD-031":3, "JD-033":3, "JD-035":3, "JD-036":3, "JD-037":3,
            "JD-097":3, "JD-098":3, "JD-101":3,
            # Peace spenders, control tools, and finishers.
            "JD-039":3, "JD-040":3, "JD-042":2, "JD-045":1,
            # Neutral sustain package.
            "JD-061":3, "JD-071":2, "JD-072":2
        },
        "Purpose": {
            # Progress engine: three copies of Daily Progress for consistency.
            "JD-046":3, "JD-047":3, "JD-048":3, "JD-049":3, "JD-054":3,
            "JD-105":3, "JD-106":3, "JD-109":3,
            # Progress support, ramp, and payoffs.
            "JD-051":3, "JD-052":3, "JD-057":2, "JD-060":1,
            # Neutral utility package.
            "JD-061":3, "JD-071":2, "JD-073":2
        }
    }
    return recipes.get(c, {})

func build_starter_deck(c: String) -> void:
    selected_deck_class = c
    saved_deck.clear()
    var recipe: Dictionary = starter_recipe(c)
    for id in recipe.keys():
        var copies := int(recipe[id])
        collection_owned[id] = maxi(int(collection_owned.get(id, 0)), copies)
        for i in range(copies):
            saved_deck.append(str(id))
    saved_decks[c] = saved_deck.duplicate()
    if saved_deck.size() != 40:
        push_error("Starter deck %s has %d cards instead of 40." % [c, saved_deck.size()])

func story_stages_for_leader(leader: String) -> Array:
    return STORY_STAGES_BY_LEADER.get(leader, STORY_STAGES_HOPE)

func stages_for_chapter(chapter: int) -> Array:
    var out: Array = []
    for stage in story_stages_for_leader(selected_class):
        if int(stage.get("chapter", 1)) == chapter:
            out.append(stage)
    return out

func chapter_count() -> int:
    return CHAPTER_META.size()

func show_story_chapters() -> void:
    # The overview screen that sits above the per-chapter roads: the whole
    # newcomer arc — nothing to a life rebuilt — read as four distinct acts
    # instead of one long, undifferentiated string of battle cards.
    if selected_class == "":
        clear_screen(); add_background(0.70)
        header("STORY MODE", "One day at a time — four chapters of the same journey")
        label("CHOOSE YOUR LEADER FIRST", Vector2(380, 245), Vector2(520, 60), 34).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        label("Story Mode plays as you — pick who you're stepping into the fight as before your first battle.", Vector2(320, 320), Vector2(640, 70), 19).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        pending_after_class_choice = show_story_chapters
        button("CHOOSE MY LEADER", Vector2(485, 420), Vector2(310, 60), show_class_choice)
        button("HOME", Vector2(40, 645), Vector2(180, 48), show_home)
        return
    clear_screen(); add_background(0.62)
    header("STORY MODE", "One day at a time — four chapters of the same journey")
    currency_bar()
    var cfg := ConfigFile.new(); cfg.load(SAVE_PATH)
    var unlocked := int(cfg.get_value("story", "unlocked_stage_%s" % selected_class, 1))

    for i in range(CHAPTER_META.size()):
        var meta: Dictionary = CHAPTER_META[i]
        var chapter_num := i + 1
        var stages := stages_for_chapter(chapter_num)
        var first_id := int(stages[0]["id"])
        var last_id := int(stages[stages.size() - 1]["id"])
        var cleared_count := 0
        for stage in stages:
            if bool(cfg.get_value("story", "cleared_%s_%d" % [selected_class, int(stage["id"])], false)):
                cleared_count += 1
        var available := first_id <= unlocked
        var complete := cleared_count == stages.size()

        var pos := Vector2(60 + i * 300, 190)
        var size_value := Vector2(270, 420)
        var panel := Panel.new(); panel.position = pos; panel.size = size_value
        panel.add_theme_stylebox_override("panel", style(class_color(str(stages[0]["class"])) if available else Color(0.18, 0.20, 0.24), 18))
        root_layer.add_child(panel)

        var badge_text := "COMPLETE" if complete else ("IN PROGRESS" if available else "LOCKED")
        var badge_color := GOLD_COLOR if complete else (Color(0.82, 0.92, 1.0) if available else Color(0.55, 0.57, 0.62))
        var badge := label("CHAPTER %d — %s" % [chapter_num, badge_text], Vector2(16, 20), Vector2(238, 22), 13, panel)
        badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        badge.add_theme_color_override("font_color", badge_color)

        var title_label := label(str(meta["title"]), Vector2(14, 50), Vector2(242, 60), 24, panel)
        title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

        var sub_label := label(str(meta["subtitle"]), Vector2(20, 116), Vector2(230, 60), 14, panel)
        sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        sub_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        sub_label.add_theme_color_override("font_color", Color(0.78, 0.84, 0.92))

        # A small progress bar instead of just text, so completion reads at a
        # glance before the player even opens the chapter.
        var bar_bg := ColorRect.new()
        bar_bg.color = Color(0.15, 0.16, 0.19)
        bar_bg.position = Vector2(24, 200)
        bar_bg.size = Vector2(222, 10)
        panel.add_child(bar_bg)
        var bar_fill := ColorRect.new()
        bar_fill.color = GOLD_COLOR if available else Color(0.35, 0.37, 0.42)
        var fill_ratio := float(cleared_count) / float(stages.size())
        bar_fill.size = Vector2(222 * fill_ratio, 10)
        bar_fill.position = Vector2(24, 200)
        panel.add_child(bar_fill)
        var progress_label := label("%d / %d STAGES CLEARED" % [cleared_count, stages.size()], Vector2(16, 218), Vector2(238, 22), 12, panel)
        progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        progress_label.add_theme_color_override("font_color", Color(0.7, 0.72, 0.78))

        if not available:
            var lock_notice := label("🔒\nFINISH THE PREVIOUS CHAPTER", Vector2(20, 260), Vector2(230, 60), 13, panel)
            lock_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
            lock_notice.add_theme_color_override("font_color", Color(0.6, 0.62, 0.68))

        var chapter_num_value := chapter_num
        var enter := button("REVISIT" if complete else ("CONTINUE" if available else "LOCKED"), Vector2(35, 350), Vector2(200, 48), func(): show_story_mode(chapter_num_value), panel)
        enter.disabled = not available

    button("HOME", Vector2(40, 645), Vector2(180, 48), show_home)

func show_story_mode(chapter: int = 1) -> void:
    clear_screen(); add_background(0.66)
    var meta: Dictionary = CHAPTER_META[chapter - 1]
    header("STORY MODE — CHAPTER %d: %s" % [chapter, str(meta["title"]).to_upper()], str(meta["subtitle"]))
    currency_bar()
    var cfg := ConfigFile.new(); cfg.load(SAVE_PATH)
    var unlocked := int(cfg.get_value("story", "unlocked_stage_%s" % selected_class, 1))
    var chapter_stages := stages_for_chapter(chapter)

    # A connecting road behind the stage cards so the chapter reads as one
    # continuous journey instead of disconnected panels — cleared and
    # unlocked stretches light up, the rest of the road stays dim. Spacing is
    # derived from the stage count instead of a fixed 234px so a chapter can
    # carry more than 5 stages (e.g. an extra named-character battle) without
    # cards overflowing the 1280-wide screen.
    var stage_count := chapter_stages.size()
    var spacing: float = 1170.0 / float(stage_count)
    var card_width: float = spacing - 24.0
    var road := ColorRect.new()
    road.color = Color(0.9, 0.82, 0.5, 0.35)
    road.position = Vector2(95, 218)
    road.size = Vector2(1090, 4)
    root_layer.add_child(road)
    for i in range(stage_count - 1):
        var stage_id := int(chapter_stages[i]["id"])
        var lit := stage_id < unlocked or bool(cfg.get_value("story", "cleared_%s_%d" % [selected_class, stage_id], false))
        var seg := ColorRect.new()
        seg.color = GOLD_COLOR if lit else Color(0.35, 0.37, 0.42, 0.4)
        seg.position = Vector2(95 + i * spacing + 5, 216)
        seg.size = Vector2(spacing - 10.0, 8)
        root_layer.add_child(seg)

    for i in range(stage_count):
        var stage: Dictionary = chapter_stages[i]
        var stage_id := int(stage["id"])
        var cleared := bool(cfg.get_value("story", "cleared_%s_%d" % [selected_class, stage_id], false))
        var available := stage_id <= unlocked
        var pos := Vector2(60 + i * spacing, 168)
        var size_value := Vector2(card_width, 400)

        # A round waypoint marker sitting on the road above each card — filled
        # gold when cleared, outlined when it's the current stage, dim/locked
        # otherwise — so progress reads at a glance before you even look at
        # the cards themselves.
        var marker := Panel.new()
        marker.position = Vector2(pos.x + size_value.x / 2.0 - 16, 200)
        marker.size = Vector2(32, 32)
        var marker_style := StyleBoxFlat.new()
        marker_style.set_corner_radius_all(16)
        marker_style.border_color = Color(0.05, 0.06, 0.09)
        marker_style.set_border_width_all(2)
        if cleared:
            marker_style.bg_color = GOLD_COLOR
        elif available:
            marker_style.bg_color = class_color(str(stage["class"]))
        else:
            marker_style.bg_color = Color(0.22, 0.24, 0.28)
        marker.add_theme_stylebox_override("panel", marker_style)
        root_layer.add_child(marker)
        var marker_label := label("✓" if cleared else str(stage_id), Vector2(0, 4), Vector2(32, 24), 14, marker)
        marker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

        var panel := Panel.new(); panel.position = pos; panel.size = size_value
        panel.clip_contents = false
        panel.add_theme_stylebox_override("panel", style(class_color(str(stage["class"])) if available else Color(0.18, 0.20, 0.24), 16))
        root_layer.add_child(panel)

        var badge_text := "COMPLETE" if cleared else ("NEXT UP" if available and stage_id == unlocked else ("UNLOCKED" if available else "LOCKED"))
        var badge_color := GOLD_COLOR if cleared else (Color(0.82, 0.92, 1.0) if available else Color(0.55, 0.57, 0.62))
        var st := label("STAGE %d — %s" % [stage_id, badge_text], Vector2(14, 16), Vector2(size_value.x - 28.0, 20), 13, panel)
        st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        st.add_theme_color_override("font_color", badge_color)

        var nm := label(str(stage["name"]), Vector2(12, 42), Vector2(size_value.x - 24.0, 56), 19, panel)
        nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

        var desc := label(str(stage["subtitle"]), Vector2(16, 102), Vector2(size_value.x - 32.0, 46), 13, panel)
        desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        desc.add_theme_color_override("font_color", Color(0.78, 0.84, 0.92))

        if available:
            # Leads with who you're actually fighting (a recurring character
            # like Dez or Nora, or a named stand-in for the stage's inner
            # struggle) with the class/deck archetype underneath it.
            var opponent := label("OPPONENT\n%s\n(%s)" % [str(stage.get("opponent_name", stage["class"])).to_upper(), str(stage["class"]).to_upper()], Vector2(16, 150), Vector2(size_value.x - 32.0, 52), 12, panel)
            opponent.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
            opponent.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
            opponent.add_theme_color_override("font_color", class_color(str(stage["class"])))
        else:
            var lock_notice := label("🔒\nCLEAR THE PREVIOUS STAGE", Vector2(16, 150), Vector2(size_value.x - 32.0, 55), 13, panel)
            lock_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
            lock_notice.add_theme_color_override("font_color", Color(0.6, 0.62, 0.68))

        var reward_parts: Array[String] = []
        if int(stage["gold"]) > 0: reward_parts.append("%d GOLD" % int(stage["gold"]))
        if int(stage["packs"]) > 0: reward_parts.append("%d PACK%s" % [int(stage["packs"]), "" if int(stage["packs"]) == 1 else "S"])
        var rw := label("REWARD\n%s" % (" + ".join(reward_parts) if not reward_parts.is_empty() else "—"), Vector2(16, 260), Vector2(size_value.x - 32.0, 46), 14, panel)
        rw.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        rw.add_theme_color_override("font_color", GOLD_COLOR)

        var play := button("REPLAY" if cleared else "BATTLE", Vector2(20, 336), Vector2(size_value.x - 40.0, 46), func(): show_story_stage_intro(stage), panel)
        play.disabled = not available

    var footer := Panel.new()
    footer.position = Vector2(0, 615)
    footer.size = Vector2(1280, 90)
    footer.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
    root_layer.add_child(footer)
    button("HOME", Vector2(40, 645), Vector2(180, 48), show_home)
    button("ALL CHAPTERS", Vector2(230, 645), Vector2(180, 48), show_story_chapters)
    button("REPLAY TRAINING", Vector2(1060, 645), Vector2(180, 48), show_first_day_intro)

func show_story_stage_intro(stage: Dictionary) -> void:
    # A short narrative beat before the fight itself, so a story stage reads
    # as a chapter of a story rather than just another entry on a battle
    # select list.
    clear_screen(); add_background(0.82)
    header("STAGE %d — %s" % [int(stage["id"]), str(stage["name"])], str(stage["subtitle"]))
    currency_bar()

    var stage_color := class_color(str(stage["class"]))

    # Every stage names an opponent (a recurring person like Dez/Nora, or a
    # stand-in like "Your Own Doubt"), but until now none of them had a face
    # -- just a text line under the quote. Giving every stage a portrait,
    # keyed off the class that actually drives its battle deck, makes each
    # fight read as facing someone rather than reading a caption.
    var portrait_frame := Panel.new()
    portrait_frame.position = Vector2(90, 190)
    portrait_frame.size = Vector2(130, 130)
    portrait_frame.add_theme_stylebox_override("panel", style(stage_color, 26))
    root_layer.add_child(portrait_frame)
    var portrait := TextureRect.new()
    portrait.texture = class_leader_texture(str(stage["class"]))
    portrait.position = Vector2(8, 8)
    portrait.size = Vector2(114, 114)
    portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    portrait.clip_contents = true
    portrait_frame.add_child(portrait)
    var portrait_caption := label(str(stage.get("opponent_name", stage["class"])).to_upper(), Vector2(85, 326), Vector2(140, 40), 13, root_layer)
    portrait_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    portrait_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    portrait_caption.add_theme_color_override("font_color", stage_color)

    var panel := Panel.new()
    panel.position = Vector2(240, 190)
    panel.size = Vector2(800, 380)
    panel.add_theme_stylebox_override("panel", style(stage_color, 20))
    root_layer.add_child(panel)

    var quote_mark := label("“", Vector2(24, 8), Vector2(60, 60), 46, panel)
    quote_mark.add_theme_color_override("font_color", stage_color)

    var story_label := label(str(stage.get("story", "")), Vector2(70, 40), Vector2(660, 190), 20, panel)
    story_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    story_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

    var opponent := label("YOUR OPPONENT: %s (%s)" % [str(stage.get("opponent_name", stage["class"])).to_upper(), str(stage["class"]).to_upper()], Vector2(40, 250), Vector2(720, 30), 16, panel)
    opponent.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    opponent.add_theme_color_override("font_color", class_color(str(stage["class"])))

    var reward_parts: Array[String] = []
    if int(stage["gold"]) > 0: reward_parts.append("%d GOLD" % int(stage["gold"]))
    if int(stage["packs"]) > 0: reward_parts.append("%d PACK%s" % [int(stage["packs"]), "" if int(stage["packs"]) == 1 else "S"])
    var rw := label("REWARD: %s" % (" + ".join(reward_parts) if not reward_parts.is_empty() else "—"), Vector2(40, 285), Vector2(720, 30), 16, panel)
    rw.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    rw.add_theme_color_override("font_color", GOLD_COLOR)

    button("BEGIN BATTLE", Vector2(490, 335), Vector2(280, 56), func(): begin_story_stage(stage), panel)
    button("BACK", Vector2(40, 335), Vector2(140, 56), func(): show_story_mode(int(stage.get("chapter", 1))), panel)
    play_story_voice(stage)

func begin_story_stage(stage: Dictionary) -> void:
    # Story Mode is a fixed, hand-placed encounter, not a freeform match:
    # the player's own leader is whoever they already chose (gated in
    # show_story_chapters, never silently assumed here) and the opponent's
    # class/deck is dictated entirely by the stage. Going through
    # start_battle()/show_match_deck_selection() would let the player pick a
    # *different* opponent than the one the story is actually about, so this
    # jumps straight to the battle intro instead of that freeform screen.
    var stage_id := int(stage["id"])
    var your_class := selected_class if selected_class != "" else "Hope"
    var cfg := _load_profile_cfg_for_partial_write()
    if cfg != null:
        var already_cleared := bool(cfg.get_value("story", "cleared_%s_%d" % [your_class, stage_id], false))
        cfg.set_value("challenge","pending_reward",0 if already_cleared else int(stage["gold"]))
        cfg.set_value("challenge","pending_packs",0 if already_cleared else int(stage["packs"]))
        cfg.set_value("challenge","name",str(stage["name"]))
        cfg.set_value("challenge","story_stage",stage_id)
        cfg.set_value("challenge","story_stage_leader",your_class)
        cfg.save(SAVE_PATH)
    var opponent_class := str(stage["class"])
    var battle_cfg := ConfigFile.new()
    battle_cfg.set_value("battle","mode","story")
    battle_cfg.set_value("battle","your_class",your_class)
    battle_cfg.set_value("battle","your_deck_mode","custom")
    battle_cfg.set_value("battle","opponent_class",opponent_class)
    battle_cfg.set_value("battle","opponent_deck_mode","prebuilt")
    # Seeds the opponent's deck build so different story stages (even ones
    # sharing a class) don't all field the exact same 40-card list — see
    # build_story_opponent_deck in main.gd.
    battle_cfg.set_value("battle","story_stage_id",stage_id)
    battle_cfg.save("user://battle_setup.cfg")
    ensure_home_music()
    await _show_battle_intro(your_class, opponent_class)

func show_recovery_road() -> void:
    clear_screen(); add_background(0.70); header("RECOVERY ROAD","Defeat increasingly overpowered class decks to earn gold"); currency_bar()
    for i in range(CHALLENGES.size()):
        var ch: Dictionary = CHALLENGES[i]
        var p := Panel.new(); p.position=Vector2(90+i*230,200); p.size=Vector2(205,350); p.add_theme_stylebox_override("panel",style(class_color(str(ch["class"])),14)); root_layer.add_child(p)
        label(str(ch["stars"]),Vector2(10,18),Vector2(185,35),20,p).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
        var n := label(str(ch["name"]),Vector2(16,70),Vector2(173,70),22,p); n.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
        label("Overpowered %s deck\n\nVictory reward\n%d GOLD" % [str(ch["class"]),int(ch["reward"])],Vector2(15,155),Vector2(175,110),16,p).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
        button("CHALLENGE",Vector2(26,285),Vector2(153,45),func(): begin_challenge(ch),p)
    status_label = label("Winning a Recovery Road battle awards the listed gold. Recovery Master also grants a 500-gold first-clear bonus.",Vector2(250,600),Vector2(780,55),17)
    status_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER

func begin_challenge(ch: Dictionary) -> void:
    var cfg := _load_profile_cfg_for_partial_write()
    if cfg != null:
        cfg.set_value("challenge","pending_reward",int(ch["reward"]))
        cfg.set_value("challenge","name",str(ch["name"]))
        cfg.save(SAVE_PATH)
    start_battle()

func show_trials() -> void:
    # The Trials: a repeatable PvE gauntlet. Each of the four leaders has
    # three escalating, fully legal decks to beat for Gold; clearing every
    # leader's Trial 3 unlocks a bonus boss, The Sponsor, whose one-time
    # rewards are cosmetic (leader-portrait skin + sleeve) plus a real,
    # normal-copy-limit card added to the collection.
    clear_screen(); add_background(0.72)
    header("THE TRIALS", "Beat each leader's escalating gauntlet for Gold. Clear every Trial 3 to call out The Sponsor.")
    currency_bar()
    var order := ["Hope", "Purpose", "Serenity", "Courage"]
    var opponent := trial_select_class if trial_select_class in order else "Hope"

    var tabs := Panel.new(); tabs.position = Vector2(90, 145); tabs.size = Vector2(700, 60); tabs.add_theme_stylebox_override("panel", style(Color(0.22, 0.22, 0.26), 12)); root_layer.add_child(tabs)
    for i in range(order.size()):
        var c: String = order[i]
        var tab_btn := button(c.to_upper(), Vector2(10 + i * 172, 8), Vector2(160, 44), func(): trial_select_class = c; show_trials(), tabs)
        var tab_style := style(class_color(c), 9)
        if c != opponent:
            tab_style.bg_color = Color(0.05, 0.06, 0.09, 0.9)
        tab_btn.add_theme_stylebox_override("normal", tab_style)
        tab_btn.add_theme_stylebox_override("hover", style(class_color(c).lightened(0.15), 9))

    var p := Panel.new(); p.position = Vector2(90, 217); p.size = Vector2(700, 380); p.add_theme_stylebox_override("panel", style(class_color(opponent), 16)); root_layer.add_child(p)
    label("%s'S GAUNTLET" % opponent.to_upper(), Vector2(20, 12), Vector2(660, 32), 22, p).add_theme_color_override("font_color", class_color(opponent))
    var tier_titles := ["TRIAL 1", "TRIAL 2", "TRIAL 3"]
    var tier_desc := [
        "A good, legal %s deck." % opponent,
        "A tougher, better-built %s deck." % opponent,
        "%s's single hardest legal deck." % opponent]
    for t in range(3):
        var tier := t + 1
        var y := 56 + t * 104
        var row := Panel.new(); row.position = Vector2(20, y); row.size = Vector2(660, 92); row.add_theme_stylebox_override("panel", style(Color(0.14, 0.14, 0.18), 10)); p.add_child(row)
        label(tier_titles[t], Vector2(16, 10), Vector2(220, 28), 18, row).add_theme_color_override("font_color", GOLD_COLOR)
        label(tier_desc[t], Vector2(16, 42), Vector2(360, 40), 13, row)
        var cleared := bool(trials_cleared.get("%s_%d" % [opponent, tier], false))
        var locked := tier > 1 and not bool(trials_cleared.get("%s_%d" % [opponent, tier - 1], false))
        var reward := int(TRIAL_GOLD_REWARDS.get(tier, 0))
        var reward_label := label(("CLEARED  •  " if cleared else "") + "%d GOLD" % reward, Vector2(390, 14), Vector2(150, 24), 14, row)
        reward_label.add_theme_color_override("font_color", Color(0.55, 0.9, 0.6) if cleared else GOLD_COLOR)
        var fight_btn := button("LOCKED" if locked else "FIGHT", Vector2(548, 20), Vector2(96, 52),
            (func(): pass) if locked else (func(): launch_trial_battle(opponent, tier)), row)
        fight_btn.disabled = locked

    var sponsor_unlocked := true
    for cls in order:
        if not bool(trials_cleared.get("%s_3" % cls, false)):
            sponsor_unlocked = false
    var sp := Panel.new(); sp.position = Vector2(810, 145); sp.size = Vector2(376, 452); sp.add_theme_stylebox_override("panel", style(Color(0.75, 0.62, 0.20), 18)); root_layer.add_child(sp)
    var sp_art := TextureRect.new()
    sp_art.texture = load("res://assets/cards/full/jd-080.jpg")
    sp_art.position = Vector2(12, 12); sp_art.size = Vector2(352, 224)
    sp_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    sp_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    sp_art.clip_contents = true
    if not sponsor_unlocked:
        sp_art.modulate = Color(0.3, 0.3, 0.3)
    sp.add_child(sp_art)
    label("THE SPONSOR", Vector2(12, 244), Vector2(352, 34), 24, sp).add_theme_color_override("font_color", GOLD_COLOR)
    var sp_desc := "Every leader's best cards, all in one deck — and he never stops running 3 copies of himself." if sponsor_unlocked else "Clear Trial 3 for every leader above to call him out."
    label(sp_desc, Vector2(12, 280), Vector2(352, 74), 14, sp)
    var sp_reward_text := "%d GOLD" % int(TRIAL_GOLD_REWARDS.get(4, 0))
    if not sponsor_defeated:
        sp_reward_text += "\n+ his leader portrait, a card sleeve, and 1 Platinum copy of The Sponsor"
    var sp_reward_label := label(sp_reward_text, Vector2(12, 356), Vector2(352, 56), 13, sp)
    sp_reward_label.add_theme_color_override("font_color", Color(0.55, 0.9, 0.6) if sponsor_defeated else GOLD_COLOR)
    var sp_btn := button("LOCKED" if not sponsor_unlocked else "FACE THE SPONSOR", Vector2(12, 400), Vector2(352, 44),
        (func(): pass) if not sponsor_unlocked else (func(): launch_trial_battle("Sponsor", 4)), sp)
    sp_btn.disabled = not sponsor_unlocked

func launch_trial_battle(opponent_class: String, tier: int) -> void:
    # Route through the deck picker before launching.
    show_trial_deck_picker(opponent_class, tier)

func _do_launch_trial_battle(opponent_class: String, tier: int, chosen_idx: int) -> void:
    var your_class := selected_class if selected_class != "" else "Hope"
    # Resolve the deck to pass into battle.
    var card_ids: Array = []
    if chosen_idx >= 0 and chosen_idx < deck_slots.size():
        card_ids = Array(deck_slots[chosen_idx].get("cards", []))
        your_class = str(deck_slots[chosen_idx].get("class", your_class))
        last_trial_deck_idx = chosen_idx
        save_profile()
    var cfg := _load_profile_cfg_for_partial_write()
    if cfg != null:
        cfg.set_value("trials", "pending_opponent", opponent_class)
        cfg.set_value("trials", "pending_tier", tier)
        cfg.save(SAVE_PATH)
    var battle_cfg := ConfigFile.new()
    battle_cfg.set_value("battle", "mode", "trial")
    battle_cfg.set_value("battle", "your_class", your_class)
    battle_cfg.set_value("battle", "your_deck_mode", "custom" if not card_ids.is_empty() else "prebuilt")
    battle_cfg.set_value("battle", "player_card_ids", card_ids)
    battle_cfg.set_value("battle", "opponent_class", opponent_class)
    battle_cfg.set_value("battle", "opponent_deck_mode", "prebuilt")
    battle_cfg.set_value("battle", "trial_tier", tier)
    battle_cfg.save("user://battle_setup.cfg")
    ensure_home_music()
    await _show_battle_intro(your_class, opponent_class)

func show_store() -> void:
    clear_screen(); add_background(0.72); header("JOURNEY'S DAWN STORE","Buy packs with earned Gold or securely through Google Play"); currency_bar()
    var p := Panel.new(); p.position=Vector2(90,145); p.size=Vector2(1100,440); p.add_theme_stylebox_override("panel",style(Color(0.72,0.46,0.95),18)); root_layer.add_child(p)
    label("BOOSTER PACKS",Vector2(25,18),Vector2(1050,45),32,p).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    label("Every pack contains 7 cards • Duplicate protection • Signature Platinum guaranteed by pack 80",Vector2(70,62),Vector2(960,35),17,p).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    button("5 PACKS\n200 GOLD",Vector2(35,120),Vector2(190,92),buy_gold,p)
    button("5 PACKS\n%s" % BillingManager.formatted_price("wf_sober_packs_5", "$2.99"),Vector2(245,120),Vector2(190,92),func(): buy_cash("wf_sober_packs_5"),p)
    button("15 PACKS\n%s" % BillingManager.formatted_price("wf_sober_packs_15", "$7.99"),Vector2(455,120),Vector2(190,92),func(): buy_cash("wf_sober_packs_15"),p)
    button("40 PACKS\n%s" % BillingManager.formatted_price("wf_sober_packs_40", "$19.99"),Vector2(665,120),Vector2(190,92),func(): buy_cash("wf_sober_packs_40"),p)
    button("80 PACKS\n%s" % BillingManager.formatted_price("wf_sober_packs_80", "$39.99"),Vector2(875,120),Vector2(190,92),func(): buy_cash("wf_sober_packs_80"),p)
    button("OPEN OWNED PACKS",Vector2(185,265),Vector2(280,58),show_pack_opening,p)
    button("BUILD A DECK",Vector2(485,265),Vector2(220,58),show_deck_builder,p)
    button("SLEEVES",Vector2(725,265),Vector2(100,58),show_sleeves,p)
    button("CHECK PURCHASES",Vector2(835,265),Vector2(165,58),BillingManager.restore_pending_purchases,p)
    button("PULL ODDS",Vector2(1010,265),Vector2(65,58),func(): show_pack_odds(show_store),p)
    var billing_text := "Google Play Billing connected" if BillingManager.is_available() else "Cash purchases activate in an installed Google Play test/release build"
    label(billing_text,Vector2(150,345),Vector2(800,34),16,p).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    status_label = label("Next guaranteed Signature Platinum: %d packs" % (80-platinum_pity),Vector2(300,610),Vector2(680,44),20); status_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER

func buy_gold() -> void:
    if gold_balance < 200:
        safe_set_text(status_label, "Not enough gold."); return
    gold_balance -= 200; pack_inventory += 5; save_profile(); show_store()

func buy_cash(product_id: String) -> void:
    safe_set_text(status_label, "Opening Google Play purchase…")
    BillingManager.buy(product_id)

func _on_billing_purchase_completed(product_id: String, pack_count: int) -> void:
    pack_inventory += pack_count
    save_profile()
    show_store()
    safe_set_text(status_label, "Purchase complete — %d packs added." % pack_count)

func _on_billing_purchase_failed(message: String) -> void:
    safe_set_text(status_label, message)

func _on_billing_products_updated(_products: Dictionary) -> void:
    if is_instance_valid(root_layer) and status_label != null:
        show_store()

var _pack_sfx_pool: Array[AudioStreamPlayer] = []

# menu.gd has no shared sfx system of its own (main.gd's play_sfx/sfx_pool
# belong to the battle scene) — this is a small self-contained pool so pack
# opening can have real audio feedback instead of being silent.
func _ensure_pack_sfx_pool() -> void:
    # clear_screen() frees every child of menu.gd (including these players)
    # whenever the screen changes, but this pool array is a script-level var
    # that survives that -- so stale/freed references must be dropped here,
    # not just skipped on an empty check, or callers can hand back a freed node.
    _pack_sfx_pool = _pack_sfx_pool.filter(func(p): return is_instance_valid(p))
    while _pack_sfx_pool.size() < 6:
        var player := AudioStreamPlayer.new()
        player.bus = "Master"
        add_child(player)
        _pack_sfx_pool.append(player)

func play_pack_sfx(sound_name: String, volume_db: float = 0.0) -> void:
    var path := "res://assets/audio/%s.wav" % sound_name
    if not ResourceLoader.exists(path):
        return
    _ensure_pack_sfx_pool()
    var target: AudioStreamPlayer = _pack_sfx_pool[0]
    for candidate in _pack_sfx_pool:
        if is_instance_valid(candidate) and not candidate.playing:
            target = candidate
            break
    if not is_instance_valid(target):
        return
    target.stream = load(path)
    target.volume_db = volume_db
    target.play()

# Recurring story characters (Dez, Nora, Reggie, Angela) have a handful of
# voiced lines tied to specific stages, organized under
# assets/audio/voices/story/<character>/. Most stages have no line for their
# opponent yet, so this is a lookup, not a guarantee — missing files are
# silently skipped.
func story_voice_path(stage: Dictionary) -> String:
    var opponent := str(stage.get("opponent_name", ""))
    var stage_id := int(stage.get("id", 0))
    var character := opponent.to_lower().replace(" ", "_")
    return "res://assets/audio/voices/story/%s/stage%02d.wav" % [character, stage_id]

func play_story_voice(stage: Dictionary) -> void:
    var path := story_voice_path(stage)
    if not ResourceLoader.exists(path):
        return
    _ensure_pack_sfx_pool()
    var target: AudioStreamPlayer = _pack_sfx_pool[0]
    for candidate in _pack_sfx_pool:
        if is_instance_valid(candidate) and not candidate.playing:
            target = candidate
            break
    if not is_instance_valid(target):
        return
    target.stream = load(path)
    target.volume_db = 0.0
    target.play()

# Shared by the pack-reveal spotlight moment: a radial burst of small glyphs,
# generalized the same way main.gd's evolution cinematics use one so pulling
# a rare card looks like a real payoff instead of a flat color flash.
func spawn_reward_sparkles(origin: Vector2, count: int, colors: Array, base_distance: float = 90.0) -> void:
    var glyphs := ["✦", "★", "•"]
    for i in range(count):
        var sparkle := Label.new()
        sparkle.text = glyphs[i % glyphs.size()]
        sparkle.add_theme_font_size_override("font_size", 16 + (i % 3) * 5)
        sparkle.add_theme_color_override("font_color", colors[i % colors.size()])
        sparkle.z_index = 200
        sparkle.mouse_filter = Control.MOUSE_FILTER_IGNORE
        sparkle.position = origin
        root_layer.add_child(sparkle)
        var angle := TAU * float(i) / float(count) + randf_range(-0.12, 0.12)
        var distance := base_distance + float(i % 4) * 16.0
        var destination := sparkle.position + Vector2(cos(angle), sin(angle)) * distance
        var sparkle_tween := create_tween().set_parallel(true)
        sparkle_tween.tween_property(sparkle, "position", destination, 0.7)
        sparkle_tween.tween_property(sparkle, "modulate:a", 0.0, 0.7)
        sparkle_tween.tween_property(sparkle, "rotation", angle, 0.7)
        sparkle_tween.finished.connect(sparkle.queue_free)

func build_pack_visual(pos: Vector2, size_value: Vector2, parent: Control = root_layer) -> Panel:
    # An actual foil-pack object — gradient body, gold foil edge, wordmark,
    # and a slow diagonal shimmer — instead of a plain rectangular button
    # with text in it, so opening a pack in the store reads as opening an
    # actual product rather than pressing a menu option.
    var pack := Panel.new()
    pack.position = pos
    pack.size = size_value
    pack.pivot_offset = size_value / 2.0
    pack.clip_contents = true
    var pack_style := StyleBoxFlat.new()
    pack_style.bg_color = Color(0.05, 0.06, 0.12, 1.0)
    pack_style.border_color = GOLD_COLOR
    pack_style.set_border_width_all(4)
    pack_style.set_corner_radius_all(16)
    pack_style.shadow_color = Color(0, 0, 0, 0.6)
    pack_style.shadow_size = 10
    pack.add_theme_stylebox_override("panel", pack_style)
    parent.add_child(pack)

    var body := TextureRect.new()
    var body_gradient := GradientTexture2D.new()
    var g := Gradient.new()
    g.colors = PackedColorArray([Color(0.16, 0.10, 0.42, 1.0), Color(0.04, 0.08, 0.22, 1.0), Color(0.02, 0.03, 0.08, 1.0)])
    g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
    body_gradient.gradient = g
    body_gradient.fill_from = Vector2(0.15, 0.0)
    body_gradient.fill_to = Vector2(0.85, 1.0)
    body.texture = body_gradient
    body.position = Vector2(4, 4)
    body.size = size_value - Vector2(8, 8)
    body.mouse_filter = Control.MOUSE_FILTER_IGNORE
    pack.add_child(body)

    var emblem := label("✦", Vector2(0, size_value.y * 0.22), size_value, 54, pack)
    emblem.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    emblem.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0, 0.9))

    var wordmark := label("JOURNEY'S DAWN", Vector2(0, size_value.y * 0.52), size_value, 20, pack)
    wordmark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    wordmark.add_theme_color_override("font_color", GOLD_COLOR)

    var subtitle := label("BOOSTER PACK  •  5 CARDS", Vector2(0, size_value.y * 0.60), size_value, 12, pack)
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_color_override("font_color", Color(0.78, 0.84, 0.94))

    var foil_line_a := ColorRect.new()
    foil_line_a.color = Color(1, 1, 1, 0.12)
    foil_line_a.position = Vector2(size_value.x * 0.18, 0)
    foil_line_a.size = Vector2(3, size_value.y)
    foil_line_a.mouse_filter = Control.MOUSE_FILTER_IGNORE
    pack.add_child(foil_line_a)
    var foil_line_b := ColorRect.new()
    foil_line_b.color = Color(1, 1, 1, 0.08)
    foil_line_b.position = Vector2(size_value.x * 0.78, 0)
    foil_line_b.size = Vector2(3, size_value.y)
    foil_line_b.mouse_filter = Control.MOUSE_FILTER_IGNORE
    pack.add_child(foil_line_b)

    var shimmer := ColorRect.new()
    shimmer.color = Color(1, 1, 1, 0.0)
    shimmer.size = Vector2(size_value.x * 0.4, size_value.y * 1.6)
    shimmer.rotation = -0.35
    shimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    pack.add_child(shimmer)
    # bind_node() ties this infinite loop to shimmer's lifetime -- without it
    # the tween keeps running against the SceneTree after the pack (and its
    # shimmer child) is freed on the next screen change, and the very next
    # loop iteration throws "Invalid assignment of property... on a base
    # object of type Nil" trying to set .position on the freed node.
    var shimmer_tween := create_tween().set_loops().bind_node(shimmer)
    shimmer_tween.tween_callback(func(): shimmer.position = Vector2(-size_value.x * 0.5, -size_value.y * 0.3); shimmer.color = Color(1, 1, 1, 0.0))
    shimmer_tween.tween_property(shimmer, "color", Color(1, 1, 1, 0.16), 0.25)
    shimmer_tween.parallel().tween_property(shimmer, "position:x", size_value.x * 1.1, 1.3).set_trans(Tween.TRANS_SINE)
    shimmer_tween.tween_property(shimmer, "color", Color(1, 1, 1, 0.0), 0.25)
    shimmer_tween.tween_interval(1.6)

    return pack

func show_pack_opening() -> void:
    clear_screen(); add_background(0.78); header("OPEN PACKS","Each opening permanently updates your collection"); currency_bar()
    if pack_inventory <= 0:
        label("NO PACKS OWNED",Vector2(390,275),Vector2(500,70),34).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
        button("RETURN TO STORE",Vector2(490,385),Vector2(300,55),show_store)
        return
    var pack_size := Vector2(260, 360)
    var pack_pos := Vector2(510, 165)
    var pack_visual := build_pack_visual(pack_pos, pack_size)
    var owned_badge := Panel.new()
    owned_badge.position = Vector2(pack_size.x - 54, -14)
    owned_badge.size = Vector2(68, 32)
    var owned_style := StyleBoxFlat.new()
    owned_style.bg_color = GOLD_COLOR
    owned_style.set_corner_radius_all(16)
    owned_style.border_color = Color(0.05, 0.06, 0.1)
    owned_style.set_border_width_all(2)
    owned_badge.add_theme_stylebox_override("panel", owned_style)
    owned_badge.z_index = 10
    pack_visual.add_child(owned_badge)
    var owned_label := label("x%d" % pack_inventory, Vector2(0, 4), Vector2(68, 24), 15, owned_badge)
    owned_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    owned_label.add_theme_color_override("font_color", Color(0.08, 0.06, 0.02))
    var tap_catcher := Button.new()
    tap_catcher.flat = true
    tap_catcher.focus_mode = Control.FOCUS_NONE
    tap_catcher.size = pack_size
    tap_catcher.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    tap_catcher.tooltip_text = "Tap to open this pack"
    tap_catcher.pressed.connect(func(): _begin_pack_open(pack_visual, tap_catcher))
    pack_visual.add_child(tap_catcher)
    label("TAP THE PACK TO OPEN IT", Vector2(390, 545), Vector2(500, 30), 17).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label("Signature Platinum pity: %d / 80 packs" % platinum_pity,Vector2(310,580),Vector2(660,30),16).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    button("VIEW PULL ODDS", Vector2(1055, 172), Vector2(170, 40), func(): show_pack_odds(show_pack_opening))

    # Bulk-open row: skips the one-at-a-time tap-and-watch flow for players
    # sitting on a stack of packs, going straight to a results grid instead.
    # Options are hidden once they can't offer anything "OPEN ALL" doesn't
    # already cover, instead of showing disabled/duplicate buttons.
    if pack_inventory > 1:
        var bulk_options: Array = []
        if pack_inventory >= 5: bulk_options.append(5)
        if pack_inventory >= 10: bulk_options.append(10)
        if pack_inventory >= 25: bulk_options.append(25)
        bulk_options.append(-1)
        var bw := 220.0
        var gap := 18.0
        var total_w: float = bw * bulk_options.size() + gap * (bulk_options.size() - 1)
        var start_x: float = (1280.0 - total_w) / 2.0
        for i in range(bulk_options.size()):
            var n: int = bulk_options[i]
            var caption := "OPEN ALL (%d)" % pack_inventory if n == -1 else "OPEN %d" % n
            button(caption, Vector2(start_x + i * (bw + gap), 622), Vector2(bw, 48), open_packs_bulk.bind(n))

func _begin_pack_open(pack_visual: Panel, tap_catcher: Button) -> void:
    # A short anticipation beat before the results screen cuts in — the pack
    # shakes, glows, and tears rather than the tap instantly jumping straight
    # to a list of cards, so opening a pack feels like an event.
    if pack_inventory <= 0 or not is_instance_valid(pack_visual):
        return
    tap_catcher.disabled = true
    play_pack_sfx("play")
    play_pack_sfx("pack_rumble", -4.0)
    var origin_rotation := pack_visual.rotation
    var origin_position := pack_visual.position
    var origin_scale := pack_visual.scale

    # Escalating shake: starts small and speeds up/intensifies toward the
    # tear, plus a subtle squash-and-stretch on top of the rotation wobble,
    # so the buildup reads as mounting pressure rather than a flat wiggle
    # played at one constant amplitude.
    var shake := create_tween()
    shake.tween_property(pack_visual, "rotation", origin_rotation - 0.035, 0.07)
    shake.tween_property(pack_visual, "rotation", origin_rotation + 0.04, 0.07)
    shake.tween_property(pack_visual, "rotation", origin_rotation - 0.05, 0.065)
    shake.tween_property(pack_visual, "rotation", origin_rotation + 0.065, 0.06)
    shake.tween_property(pack_visual, "rotation", origin_rotation - 0.07, 0.055)
    shake.tween_property(pack_visual, "rotation", origin_rotation + 0.05, 0.05)
    shake.tween_property(pack_visual, "rotation", origin_rotation, 0.05)
    shake.parallel().tween_property(pack_visual, "position", origin_position + Vector2(0, -8), 0.415).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    shake.parallel().tween_property(pack_visual, "scale", origin_scale * Vector2(1.015, 0.985), 0.19).set_trans(Tween.TRANS_SINE)
    shake.chain().tween_property(pack_visual, "scale", origin_scale, 0.09).set_trans(Tween.TRANS_SINE)
    await shake.finished

    var flash := ColorRect.new()
    flash.color = Color(1, 1, 1, 0.0)
    flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
    flash.z_index = 500
    root_layer.add_child(flash)
    play_pack_sfx("pack_tear")
    play_pack_sfx("draw", -6.0)
    # A generic gold energy burst at the tear point itself -- the actual
    # pull rarity isn't rolled until open_pack() runs after this animation,
    # so this is deliberately not rarity-colored, just a dramatic accent
    # that any tear gets.
    var tear_burst := ColorRect.new()
    tear_burst.color = Color(1.0, 0.85, 0.4, 0.6)
    tear_burst.size = Vector2(90, 90)
    tear_burst.position = pack_visual.position + pack_visual.size / 2.0 - tear_burst.size / 2.0
    tear_burst.pivot_offset = tear_burst.size / 2.0
    tear_burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
    tear_burst.z_index = 40
    root_layer.add_child(tear_burst)
    tear_burst.scale = Vector2(0.2, 0.2)
    var tear_burst_tween := create_tween().set_parallel(true)
    tear_burst_tween.tween_property(tear_burst, "scale", Vector2(2.0, 2.0), 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tear_burst_tween.tween_property(tear_burst, "color:a", 0.0, 0.36)
    tear_burst_tween.chain().tween_callback(tear_burst.queue_free)
    # The tear itself now overshoots wider before the flash cuts to white
    # (was a flat 1.15 scale-up) so the pack visibly rips open instead of
    # just puffing up in place.
    var tear := create_tween().set_parallel(true)
    tear.tween_property(pack_visual, "scale", origin_scale * 1.22, 0.17).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tear.tween_property(pack_visual, "rotation", origin_rotation + 0.03, 0.17)
    tear.tween_property(flash, "color:a", 0.9, 0.15)
    await tear.finished
    flash.color.a = 0.9
    # A short held beat on full white before it clears -- the instant cut
    # from tear to fade felt like a glitch rather than a deliberate flash.
    await get_tree().create_timer(0.08).timeout
    var settle := create_tween()
    settle.tween_property(flash, "color:a", 0.0, 0.24)
    await settle.finished
    flash.queue_free()

    open_pack()

func _roll_one_pack() -> Dictionary:
    # Single source of truth for one pack's pull (pity counter, rarity rolls,
    # collection grant) so the animated single-open flow and the bulk opener
    # below always share identical odds and pity math -- duplicating this
    # loop for a "fast path" would be exactly how the two silently drift out
    # of sync with each other over time.
    pack_inventory -= 1; packs_opened += 1; platinum_pity += 1
    # Platinum can appear on any card via the 0.2% random roll, or is
    # guaranteed on card 7 once the pity counter reaches 80.
    # Legendary is guaranteed once legendary_pity reaches 49 cards drawn (7 packs).
    var guaranteed_platinum := platinum_pity >= 80
    var pulled: Array = []
    var got_platinum := false
    for i in range(7):
        legendary_pity += 1
        var rarity := roll_rarity(i == 6, guaranteed_platinum and i == 6)
        # Upgrade to Legendary if pity threshold hit and card isn't already Legendary+.
        if legendary_pity >= 49 and rarity not in ["Legendary", "Platinum"]:
            rarity = "Legendary"
        # Reset legendary pity on any Legendary-or-better pull.
        if rarity in ["Legendary", "Platinum"]:
            legendary_pity = 0
        if rarity == "Platinum": got_platinum = true
        var cd := random_card_of_rarity(rarity)
        var dup_info := add_card_to_collection(cd)
        # Duplicate/vial info is stamped onto a *copy* of the card dict, not
        # the shared entry inside `cards` -- mutating the master card list
        # here would leak this pull's duplicate status onto every future
        # pull of the same card.
        var pulled_cd := cd.duplicate()
        pulled_cd["_dup_info"] = dup_info
        # 0.5% per-card shiny chance — draw-only, cannot be crafted.
        # Shiny tracks in collection_shiny_owned independently of regular copies.
        if randf() < 0.005:
            pulled_cd["is_shiny"] = true
            pulled_cd["_shiny_dup_info"] = add_shiny_to_collection(pulled_cd)
        pulled.append(pulled_cd)
    # Reset pity whenever a Platinum lands, whether random or pity-triggered.
    if got_platinum: platinum_pity = 0
    # 5% chance per pack to also drop a pullable sleeve the player doesn't own yet.
    var sleeve_pulled := ""
    var pullable := _sleeve_catalog().filter(func(s): return s.get("pullable", false) and not sleeve_owned(s["id"]))
    if not pullable.is_empty() and randf() < 0.05:
        var chosen: Dictionary = pullable[randi() % pullable.size()]
        sleeve_pulled = chosen["id"]
        owned_sleeves.append(sleeve_pulled)
    return {"pulled": pulled, "platinum_hit": got_platinum, "sleeve_pulled": sleeve_pulled}

func open_pack() -> void:
    if pack_inventory <= 0: return
    var result := _roll_one_pack()
    save_profile(); show_pack_results(result["pulled"], result["platinum_hit"], result.get("sleeve_pulled", ""))

func open_packs_bulk(requested: int) -> void:
    # requested == -1 means "open everything owned". Rolls all packs upfront
    # so the intro summary is accurate, then reveals them one-at-a-time so
    # Legendary/Platinum pulls each still get their spotlight moment.
    var count: int = pack_inventory if requested == -1 else min(requested, pack_inventory)
    if count <= 0: return
    var pack_results: Array = []
    var all_pulled: Array = []
    var platinum_count := 0
    for i in range(count):
        var result := _roll_one_pack()
        pack_results.append(result)
        all_pulled.append_array(result["pulled"])
        if result["platinum_hit"]: platinum_count += 1
    save_profile()
    _show_bulk_intro(pack_results, all_pulled, count, platinum_count)

func _show_bulk_intro(pack_results: Array, all_pulled: Array, pack_count: int, platinum_count: int) -> void:
    clear_screen(); add_background(0.92); currency_bar()

    # Tally rarity counts and duplicate vials across all pulled cards.
    var rarity_counts: Dictionary = {}
    var total_dup_vials := 0
    for cd in all_pulled:
        var r: String = str(cd.get("rarity", "Bronze"))
        rarity_counts[r] = rarity_counts.get(r, 0) + 1
        var dup_info: Dictionary = cd.get("_dup_info", {})
        if dup_info.get("is_duplicate", false):
            total_dup_vials += int(dup_info.get("vials", 0))

    # ── Header ────────────────────────────────────────────────────────────────
    var title_lbl := Label.new()
    title_lbl.text = "OPENING %d PACKS" % pack_count
    title_lbl.position = Vector2(190, 18)   # starts 30 px above final resting place
    title_lbl.size = Vector2(900, 76)
    title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title_lbl.add_theme_font_size_override("font_size", 52)
    title_lbl.add_theme_color_override("font_color", GOLD_COLOR)
    title_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
    title_lbl.add_theme_constant_override("shadow_offset_x", 3)
    title_lbl.add_theme_constant_override("shadow_offset_y", 3)
    title_lbl.modulate.a = 0.0
    root_layer.add_child(title_lbl)

    var subtitle_parts: Array = []
    if platinum_count > 0:
        subtitle_parts.append("★ %d Signature Platinum" % platinum_count)
    var leg_count: int = rarity_counts.get("Legendary", 0)
    if leg_count > 0:
        subtitle_parts.append("%d Legendary" % leg_count)
    var epic_count: int = rarity_counts.get("Epic", 0)
    if epic_count > 0:
        subtitle_parts.append("%d Epic" % epic_count)
    if total_dup_vials > 0:
        subtitle_parts.append("+%d Vials" % total_dup_vials)
    var subtitle_text: String = "  •  ".join(subtitle_parts) if not subtitle_parts.is_empty() else "%d cards total" % all_pulled.size()
    var sub_lbl := label(subtitle_text, Vector2(190, 98), Vector2(900, 36), 20)
    sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    sub_lbl.modulate.a = 0.0

    # ── Rarity breakdown pills ─────────────────────────────────────────────────
    var rarities_present: Array = []
    for r in BULK_RARITY_ORDER:
        if rarity_counts.get(r, 0) > 0:
            rarities_present.append(r)

    var pill_h := 46.0
    var pill_gap := 10.0
    var total_pill_h: float = rarities_present.size() * pill_h + (rarities_present.size() - 1) * pill_gap
    var pills_start_y: float = 154.0 + (330.0 - total_pill_h) / 2.0

    var breakdown_pills: Array = []
    for i in range(rarities_present.size()):
        var r: String = rarities_present[i]
        var cnt: int = rarity_counts.get(r, 0)
        var row_y: float = pills_start_y + i * (pill_h + pill_gap)
        var rcolor := card_rarity_color(r)

        var pill := Panel.new()
        pill.position = Vector2(800.0, row_y)   # starts off-screen right; slides to 340
        pill.size = Vector2(600, pill_h)
        var pill_style := StyleBoxFlat.new()
        pill_style.bg_color = Color(rcolor.r, rcolor.g, rcolor.b, 0.14)
        pill_style.border_color = rcolor
        pill_style.set_border_width_all(1)
        pill_style.set_corner_radius_all(23)
        pill.add_theme_stylebox_override("panel", pill_style)
        pill.modulate.a = 0.0
        root_layer.add_child(pill)

        var r_lbl := label(r.to_upper(), Vector2(22, 7), Vector2(360, pill_h - 14), 18, pill)
        r_lbl.add_theme_color_override("font_color", rcolor)
        r_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

        var cnt_lbl := label("× %d" % cnt, Vector2(420, 7), Vector2(160, pill_h - 14), 20, pill)
        cnt_lbl.add_theme_color_override("font_color", Color.WHITE)
        cnt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        cnt_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

        breakdown_pills.append(pill)

    # ── Buttons ────────────────────────────────────────────────────────────────
    var on_reveal := func(): _reveal_packs_sequential(pack_results, all_pulled, pack_count, platinum_count)
    var on_skip   := func(): show_bulk_pack_results(all_pulled, pack_count, platinum_count)
    var reveal_btn := button("▶  REVEAL PACKS", Vector2(390, 562), Vector2(310, 56), on_reveal)
    reveal_btn.modulate.a = 0.0
    var skip_btn := button("SKIP TO SUMMARY", Vector2(714, 562), Vector2(230, 56), on_skip)
    skip_btn.modulate.a = 0.0

    # Fire the entrance animation (fire-and-forget).
    _animate_bulk_intro(title_lbl, sub_lbl, breakdown_pills, reveal_btn, skip_btn,
                        platinum_count, leg_count, rarity_counts)

func _animate_bulk_intro(title_lbl: Label, sub_lbl: Label, pills: Array,
                         reveal_btn: BaseButton, skip_btn: BaseButton,
                         platinum_count: int, leg_count: int, rarity_counts: Dictionary) -> void:
    # Title drops in from slightly above with a back-ease overshoot.
    var title_in := create_tween().set_parallel(true)
    title_in.tween_property(title_lbl, "modulate:a", 1.0, 0.30).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    title_in.tween_property(title_lbl, "position:y", 48.0, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    await title_in.finished

    # Subtitle fades in.
    var sub_in := create_tween()
    sub_in.tween_property(sub_lbl, "modulate:a", 1.0, 0.22)
    await sub_in.finished

    # Rarity pills slide in from the right, staggered.
    for pill in pills:
        if not is_instance_valid(pill):
            continue
        var pill_in := create_tween().set_parallel(true)
        pill_in.tween_property(pill, "modulate:a", 1.0, 0.20).set_trans(Tween.TRANS_QUAD)
        pill_in.tween_property(pill, "position:x", 340.0, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        await get_tree().create_timer(0.07).timeout

    await get_tree().create_timer(0.10).timeout

    # Fanfare + sparkles for high-rarity hauls.
    if platinum_count > 0:
        play_pack_sfx("platinum_fanfare")
        spawn_reward_sparkles(Vector2(640, 340), 32, [GOLD_COLOR, Color(1, 1, 1)], 170.0)
        await get_tree().create_timer(0.28).timeout
    elif leg_count > 0:
        play_pack_sfx("legendary_fanfare", -3.0)
        spawn_reward_sparkles(Vector2(640, 340), 18, [card_rarity_color("Legendary"), Color(1, 1, 1)], 130.0)
        await get_tree().create_timer(0.20).timeout

    # Reveal + skip buttons fade in together.
    if is_instance_valid(reveal_btn) and is_instance_valid(skip_btn):
        var btn_in := create_tween().set_parallel(true)
        btn_in.tween_property(reveal_btn, "modulate:a", 1.0, 0.22)
        btn_in.tween_property(skip_btn,   "modulate:a", 1.0, 0.22)
        await btn_in.finished
        # Gentle pulse on the reveal button so it draws the eye.
        var pulse := create_tween().set_loops(3).bind_node(reveal_btn)
        pulse.tween_property(reveal_btn, "modulate:a", 0.65, 0.28)
        pulse.tween_property(reveal_btn, "modulate:a", 1.00, 0.28)

func _reveal_packs_sequential(pack_results: Array, all_pulled: Array, pack_count: int, platinum_count: int) -> void:
    _open_next_pack_in_sequence(pack_results, all_pulled, pack_count, platinum_count, 0)

func _open_next_pack_in_sequence(pack_results: Array, all_pulled: Array,
                                  pack_count: int, platinum_count: int, idx: int) -> void:
    if idx >= pack_results.size():
        show_bulk_pack_results(all_pulled, pack_count, platinum_count)
        return
    var result: Dictionary  = pack_results[idx]
    var pulled: Array       = result["pulled"]
    var plat_hit: bool      = result["platinum_hit"]
    var on_next := func(): _open_next_pack_in_sequence(pack_results, all_pulled, pack_count, platinum_count, idx + 1)
    _show_sequential_pack_reveal(pulled, plat_hit, idx + 1, pack_results.size(),
                                  all_pulled, pack_count, platinum_count, on_next)

func _show_sequential_pack_reveal(pulled: Array, platinum_hit: bool,
                                   pack_num: int, total_packs: int,
                                   all_pulled: Array, pack_count: int, plat_total: int,
                                   on_next: Callable) -> void:
    clear_screen(); add_background(0.80)
    var pack_label := "PACK %d OF %d" % [pack_num, total_packs]
    header(pack_label, "SIGNATURE PLATINUM!" if platinum_hit else "Cards added to your collection")
    currency_bar()

    var backs: Array[Panel] = []
    # 7 cards × 168 px + 6 × 10 px gap = 1,258 px — fits the 1,280 px viewport.
    for i in range(pulled.size()):
        var pos := Vector2(22 + i * 178, 192)
        var back := pack_card_back(pos, Vector2(168, 255))
        root_layer.add_child(back)
        backs.append(back)

    # NEXT PACK / DONE button — disabled until reveal finishes so Legendary/
    # Platinum spotlights can't be skipped accidentally; enabled the instant
    # animations complete, then pulses to signal it's ready.
    var next_caption: String
    if pack_num >= total_packs:
        next_caption = "VIEW SUMMARY"
    else:
        next_caption = "NEXT PACK  (%d remaining)" % (total_packs - pack_num)
    var next_btn := button(next_caption, Vector2(390, 468), Vector2(390, 55), on_next)
    next_btn.disabled = true

    # Skip-to-summary always available so a player opening 25 packs isn't
    # forced through every single animation if they just want the results.
    var on_skip := func(): show_bulk_pack_results(all_pulled, pack_count, plat_total)
    button("SKIP TO SUMMARY", Vector2(793, 468), Vector2(222, 55), on_skip)

    _enable_next_after_reveal(pulled, backs, platinum_hit, next_btn)

func _enable_next_after_reveal(pulled: Array, backs: Array, platinum_hit: bool, next_btn: BaseButton) -> void:
    # Awaits the full reveal animation (including any spotlight sequences), then
    # enables the next-pack button and pulses it to draw the player's eye.
    await _animate_pack_reveal(pulled, backs, platinum_hit)
    if not is_instance_valid(next_btn):
        return
    next_btn.disabled = false
    var pulse := create_tween().set_loops(4).bind_node(next_btn)
    pulse.tween_property(next_btn, "modulate:a", 0.55, 0.25)
    pulse.tween_property(next_btn, "modulate:a", 1.00, 0.25)

func show_pack_odds(return_screen: Callable) -> void:
    # Required disclosure for real-money pack purchases (Apple/Google both
    # treat randomized-rarity packs as loot boxes and require the odds to be
    # shown before purchase) -- this must mirror roll_rarity()/_roll_one_pack()
    # exactly, or the disclosure silently drifts out of sync with the real
    # drop table the next time odds are tuned.
    clear_screen(); add_background(0.80); header("PULL ODDS", "Odds are identical for every pack, whether earned free or bought with cash")
    var p := Panel.new(); p.position = Vector2(140, 118); p.size = Vector2(1000, 470)
    p.add_theme_stylebox_override("panel", style()); root_layer.add_child(p)
    label("Every pack = 7 cards. Cards 1-6 roll independently. Card 7 is Silver-or-better. Legendary guaranteed within 7 packs drawn. Platinum pity at 80 packs.", Vector2(30, 14), Vector2(940, 40), 16, p).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

    label("CARDS 1-6  (EACH ROLLED INDEPENDENTLY)", Vector2(30, 66), Vector2(460, 26), 17, p).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var rows_common := [["Platinum", 0.2], ["Legendary", 0.8], ["Epic", 3.5], ["Gold", 11.0], ["Silver", 27.0], ["Bronze", 57.5]]
    var y := 98
    for row in rows_common:
        var rarity: String = row[0]
        var pct: float = row[1]
        var l := label(rarity, Vector2(30, y), Vector2(220, 28), 17, p)
        l.add_theme_color_override("font_color", card_rarity_color(rarity))
        label("%.1f%%" % pct, Vector2(280, y), Vector2(180, 28), 17, p).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        y += 34

    label("CARD 7  (GUARANTEED SILVER-OR-BETTER)", Vector2(520, 66), Vector2(460, 26), 17, p).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var rows_slot7 := [["Platinum", 0.2], ["Legendary", 0.8], ["Epic", 3.5], ["Gold", 11.0], ["Silver", 84.5]]
    y = 98
    for row in rows_slot7:
        var rarity: String = row[0]
        var pct: float = row[1]
        var l2 := label(rarity, Vector2(520, y), Vector2(220, 28), 17, p)
        l2.add_theme_color_override("font_color", card_rarity_color(rarity))
        label("%.1f%%" % pct, Vector2(770, y), Vector2(180, 28), 17, p).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        y += 34

    var pity_panel := Panel.new(); pity_panel.position = Vector2(30, 268); pity_panel.size = Vector2(940, 104)
    pity_panel.add_theme_stylebox_override("panel", solid_style(Color(0.18, 0.14, 0.05), 10)); p.add_child(pity_panel)
    label("PITY GUARANTEES", Vector2(20, 8), Vector2(900, 24), 16, pity_panel).add_theme_color_override("font_color", GOLD_COLOR)
    label("Legendary: guaranteed within 7 packs (49 cards) drawn. Currently at %d / 49 cards since your last one." % legendary_pity, Vector2(20, 34), Vector2(900, 26), 15, pity_panel)
    label("Signature Platinum: guaranteed within 80 packs. Currently at %d / 80 packs since your last one." % platinum_pity, Vector2(20, 62), Vector2(900, 26), 15, pity_panel)

    var shiny_panel := Panel.new(); shiny_panel.position = Vector2(30, 360); shiny_panel.size = Vector2(940, 52)
    shiny_panel.add_theme_stylebox_override("panel", solid_style(Color(0.10, 0.06, 0.18), 10)); p.add_child(shiny_panel)
    var shiny_title := label("✦  SHINY VARIANTS  (0.5% per card drawn)", Vector2(20, 6), Vector2(900, 22), 15, shiny_panel)
    shiny_title.add_theme_color_override("font_color", Color(0.85, 0.62, 1.0))
    label("Any card drawn from a pack has an independent 0.5% chance to be a shiny holographic variant. Shinies can only be drawn — never crafted.", Vector2(20, 28), Vector2(900, 20), 13, shiny_panel)
    label("Odds apply the same way whether the pack was earned for free (story, login, Trials, VS Mode) or purchased with real money.", Vector2(30, 420), Vector2(940, 30), 15, p).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

    button("BACK", Vector2(550, 610), Vector2(180, 50), return_screen)

func roll_rarity(guaranteed_silver: bool, force_platinum: bool) -> String:
    if force_platinum: return "Platinum"
    var r := randi_range(1,1000)
    # Rates (per card):
    #   Platinum   0.2%   rare random pull; pity backstop at 80 packs
    #   Legendary  0.8%   ~1 in 18 packs to see one across 7 cards
    #   Epic       3.5%   noticeably more common than Legendary
    #   Gold      11.0%
    #   Silver    27.0%   card 7 always Silver-or-better (Bronze impossible there)
    #   Bronze    57.5%
    if r <= 2:   return "Platinum"
    if r <= 10:  return "Legendary"
    if r <= 45:  return "Epic"
    if r <= 155: return "Gold"
    if guaranteed_silver or r <= 425: return "Silver"
    return "Bronze"

func random_card_of_rarity(rarity: String) -> Dictionary:
    var pool: Array = []
    for cd in cards:
        if str(cd["rarity"]) == rarity: pool.append(cd)
    if pool.is_empty(): pool = cards
    return pool[randi_range(0,pool.size()-1)]

func add_card_to_collection(cd: Dictionary) -> Dictionary:
    # Returns whether this pull was a duplicate (already owned at its copy
    # limit) and, if so, how many Vials it was converted to -- callers that
    # display the pull (pack reveal, bulk results) need this to tell the
    # player a duplicate was silently turned into currency instead of
    # letting it look identical to a brand-new card.
    var id := str(cd["id"]); var rarity := str(cd["rarity"]); var owned := int(collection_owned.get(id,0)); var limit := int(COPY_LIMITS.get(rarity,1))
    if owned >= limit:
        var vials := int(DUST_VALUES.get(rarity,10))
        dust_balance += vials
        return {"is_duplicate": true, "vials": vials}
    else:
        collection_owned[id] = owned + 1
        return {"is_duplicate": false, "vials": 0}

func add_shiny_to_collection(cd: Dictionary) -> Dictionary:
    # Shiny variants track in a parallel dict; same COPY_LIMITS apply but
    # shiny dupes are worth triple the regular Vial value — a shiny duplicate
    # is far rarer than a regular one so it should feel meaningfully more
    # valuable. Shiny cards cannot be crafted, only drawn from packs.
    var id := str(cd["id"]); var rarity := str(cd["rarity"])
    var owned := int(collection_shiny_owned.get(id, 0))
    var limit := int(COPY_LIMITS.get(rarity, 1))
    if owned >= limit:
        var vials := int(DUST_VALUES.get(rarity, 10)) * 3
        dust_balance += vials
        return {"is_duplicate": true, "vials": vials}
    else:
        collection_shiny_owned[id] = owned + 1
        return {"is_duplicate": false, "vials": 0}

func pack_card_back(pos: Vector2, size_value: Vector2) -> Panel:
    # A face-down placeholder so the reveal reads as an actual pack being
    # opened one card at a time, instead of five cards just appearing flat
    # and static on the screen at once.
    var back := Panel.new()
    back.position = pos
    back.size = size_value
    back.pivot_offset = size_value / 2.0
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.05, 0.09, 0.16, 1.0)
    style.border_color = Color(0.62, 0.72, 0.92, 0.9)
    style.set_border_width_all(3)
    style.set_corner_radius_all(12)
    style.shadow_color = Color(0, 0, 0, 0.55)
    style.shadow_size = 6
    back.add_theme_stylebox_override("panel", style)
    var glyph := label("✦", Vector2(0, size_value.y / 2.0 - 34), size_value, 40, back)
    glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    glyph.add_theme_color_override("font_color", Color(0.72, 0.82, 1.0, 0.85))
    var wordmark := label("JOURNEY'S\nDAWN", Vector2(0, size_value.y / 2.0 + 16), size_value, 12, back)
    wordmark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    wordmark.add_theme_color_override("font_color", Color(0.72, 0.82, 1.0, 0.6))
    return back

func pack_rarity_burst(center: Vector2, rarity: String) -> void:
    # A brief radial flash sized and colored by rarity so a Legendary/Platinum
    # pull actually feels bigger than a Bronze one, instead of every card
    # revealing with identical, flat presentation.
    var scale_by_rarity := {"Bronze": 60.0, "Silver": 75.0, "Gold": 95.0, "Signature Gold": 95.0, "Epic": 115.0, "Legendary": 140.0, "Platinum": 175.0, "Shiny": 130.0}
    var radius: float = scale_by_rarity.get(rarity, 70.0)
    var glow := ColorRect.new()
    glow.color = card_rarity_color(rarity)
    glow.color.a = 0.55
    glow.size = Vector2(radius, radius)
    glow.position = center - glow.size / 2.0
    glow.pivot_offset = glow.size / 2.0
    glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
    glow.z_index = 40
    root_layer.add_child(glow)
    glow.scale = Vector2(0.2, 0.2)
    var burst_tween := create_tween().set_parallel(true)
    burst_tween.tween_property(glow, "scale", Vector2(1.0, 1.0), 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    burst_tween.tween_property(glow, "color:a", 0.0, 0.42)
    burst_tween.chain().tween_callback(glow.queue_free)

func show_pack_results(pulled: Array, platinum_hit: bool, sleeve_pulled: String = "") -> void:
    clear_screen(); add_background(0.80)
    var subtitle := "SIGNATURE PLATINUM!" if platinum_hit else "Cards added to your collection"
    if sleeve_pulled != "":
        var sname := _sleeve_name_for_id(sleeve_pulled)
        subtitle = ("SIGNATURE PLATINUM!  +  " if platinum_hit else "") + "✦ SLEEVE UNLOCKED: %s ✦" % sname
    header("PACK OPENED", subtitle); currency_bar()
    if sleeve_pulled != "":
        var banner := Panel.new()
        banner.position = Vector2(340, 130); banner.size = Vector2(600, 36)
        var bs := StyleBoxFlat.new()
        bs.bg_color = Color(0.12, 0.08, 0.22, 0.92)
        bs.border_color = Color(0.85, 0.72, 0.25, 0.9); bs.set_border_width_all(2); bs.set_corner_radius_all(10)
        banner.add_theme_stylebox_override("panel", bs); root_layer.add_child(banner)
        label("✦ New sleeve added to your collection — equip it in the Store ✦", Vector2(0, 6), Vector2(600, 24), 14, banner).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var backs: Array[Panel] = []
    # 7 cards × 168 px + 6 × 10 px gap = 1,258 px — fits the 1,280 px viewport.
    # Old step of 244 placed card 7 at x = 1,519, completely off-screen.
    for i in range(pulled.size()):
        var pos := Vector2(22 + i * 178, 186 if sleeve_pulled != "" else 178)
        var back := pack_card_back(pos, Vector2(168, 300))
        root_layer.add_child(back)
        backs.append(back)
    button("OPEN ANOTHER (%d)" % pack_inventory,Vector2(255,550),Vector2(230,55),show_pack_opening)
    button("CRAFT CARDS",Vector2(495,550),Vector2(190,55),show_craft_screen)
    button("COLLECTION",Vector2(695,550),Vector2(180,55),show_collection)
    button("DECK BUILDER",Vector2(885,550),Vector2(200,55),show_deck_builder)
    # Fire-and-forget: the reveal animation must never gate the buttons above
    # from appearing (a stuck tween here should never be able to strand the
    # player on this screen with no way forward).
    _animate_pack_reveal(pulled, backs, platinum_hit)

const BULK_RARITY_ORDER := ["Platinum", "Legendary", "Epic", "Signature Gold", "Gold", "Silver", "Bronze"]

func show_bulk_pack_results(pulled: Array, pack_count: int, platinum_count: int) -> void:
    # The one-at-a-time flip/spotlight sequence in show_pack_results doesn't
    # scale to dozens of cards -- this shows every pull at once, best rarity
    # first, so a big bulk-open still reads as "here's everything you got"
    # instead of forcing a long wait through repeated small animations.
    clear_screen(); add_background(0.80)
    # Per-card "DUPLICATE +N VIALS" badges tell the story of one card; players
    # opening dozens of packs at once also want the single number "how much
    # did I just get overall", which no individual badge answers on its own.
    var total_dup_vials := 0
    for cd in pulled:
        var dup_info: Dictionary = cd.get("_dup_info", {})
        if dup_info.get("is_duplicate", false):
            total_dup_vials += int(dup_info.get("vials", 0))
    var subtitle := "%d packs opened" % pack_count
    if platinum_count > 0:
        subtitle += "  •  %d SIGNATURE PLATINUM!" % platinum_count
    if total_dup_vials > 0:
        subtitle += "  •  +%d VIALS FROM DUPLICATES" % total_dup_vials
    header("PACKS OPENED", subtitle); currency_bar()

    # Build per-rarity counts and display them between the header and card grid
    # so players opening large batches can see at a glance how many Epics,
    # Legendaries, etc. they pulled without having to count badges themselves.
    var rarity_counts := {}
    for cd in pulled:
        var r: String = str(cd.get("rarity", "Bronze"))
        rarity_counts[r] = rarity_counts.get(r, 0) + 1
    var breakdown_parts: Array = []
    for r in BULK_RARITY_ORDER:
        var cnt: int = rarity_counts.get(r, 0)
        if cnt > 0:
            breakdown_parts.append("%d %s" % [cnt, r])
    if not breakdown_parts.is_empty():
        var breakdown_label := label(
            "  •  ".join(breakdown_parts),
            Vector2(28, 112), Vector2(810, 54), 15
        )
        breakdown_label.add_theme_color_override("font_color", GOLD_COLOR)
        breakdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

    var sorted_pulled: Array = pulled.duplicate()
    sorted_pulled.sort_custom(func(a, b):
        var ra: int = BULK_RARITY_ORDER.find(str(a.get("rarity", "Bronze")))
        var rb: int = BULK_RARITY_ORDER.find(str(b.get("rarity", "Bronze")))
        if ra == rb: return str(a.get("name","")) < str(b.get("name",""))
        return ra < rb
    )

    var binder := Panel.new()
    binder.position = Vector2(28, 176)
    binder.size = Vector2(1224, 388)
    var binder_style := StyleBoxFlat.new()
    binder_style.bg_color = Color(0.01, 0.02, 0.045, 0.78)
    binder_style.border_color = GOLD_COLOR
    binder_style.set_border_width_all(2)
    binder_style.set_corner_radius_all(14)
    binder.add_theme_stylebox_override("panel", binder_style)
    root_layer.add_child(binder)
    var scroll := ScrollContainer.new()
    scroll.position = Vector2(12, 12)
    scroll.size = Vector2(1200, 364)
    binder.add_child(scroll)
    var grid := GridContainer.new()
    grid.columns = 7
    grid.add_theme_constant_override("h_separation", 14)
    grid.add_theme_constant_override("v_separation", 16)
    scroll.add_child(grid)
    for cd in sorted_pulled:
        var wrap := VBoxContainer.new()
        wrap.custom_minimum_size = Vector2(160, 246)
        var cp := card_panel(cd, Vector2.ZERO, Vector2(160, 236))
        cp.modulate.a = 0.0
        wrap.add_child(cp)
        grid.add_child(wrap)

    button("OPEN ANOTHER (%d)" % pack_inventory, Vector2(255, 580), Vector2(230, 55), show_pack_opening)
    button("CRAFT CARDS", Vector2(495, 580), Vector2(190, 55), show_craft_screen)
    button("COLLECTION", Vector2(695, 580), Vector2(180, 55), show_collection)
    button("DECK BUILDER", Vector2(885, 580), Vector2(200, 55), show_deck_builder)

    # Bulk-open trades the per-card flip/spotlight sequence for speed, but it
    # shouldn't feel silent or instant either -- one rarity-appropriate sound
    # (biggest pull wins) plus a fast staggered fade-in still sells "a lot of
    # cards just landed" without making the player wait through dozens of
    # individual animations.
    var best_rarity := "Bronze"
    for cd in sorted_pulled:
        if BULK_RARITY_ORDER.find(str(cd.get("rarity", "Bronze"))) < BULK_RARITY_ORDER.find(best_rarity):
            best_rarity = str(cd.get("rarity", "Bronze"))
    if platinum_count > 0:
        play_pack_sfx("platinum_fanfare")
    elif best_rarity == "Legendary":
        play_pack_sfx("legendary_fanfare", -2.0)
    else:
        play_pack_sfx(str(PACK_REVEAL_SFX.get(best_rarity, "draw")))
    _stagger_fade_in_grid(grid)

func _stagger_fade_in_grid(grid: GridContainer) -> void:
    for i in range(grid.get_child_count()):
        var wrap: Node = grid.get_child(i)
        if wrap.get_child_count() == 0:
            continue
        var cp: Control = wrap.get_child(0)
        var fade := create_tween().bind_node(cp)
        fade.tween_interval(min(float(i) * 0.012, 0.5))
        fade.tween_property(cp, "modulate:a", 1.0, 0.18)

# sfx grows with rarity so a bronze pull stays quick/quiet and a
# legendary/platinum pull actually announces itself.
const PACK_REVEAL_SFX := {"Bronze": "draw", "Silver": "draw", "Gold": "evolve", "Signature Gold": "evolve", "Epic": "evolve_new", "Legendary": "evolve_cinematic", "Platinum": "platinum"}
const PACK_REVEAL_TITLE := {"Epic": "EPIC PULL!", "Legendary": "LEGENDARY PULL!", "Platinum": "SIGNATURE PLATINUM!", "Shiny": "✦  SHINY PULL!  ✦"}

func _animate_pack_reveal(pulled: Array, backs: Array, platinum_hit: bool) -> void:
    for i in range(pulled.size()):
        await get_tree().create_timer(0.30).timeout
        if i >= backs.size() or not is_instance_valid(backs[i]):
            continue
        var back: Panel = backs[i]
        var pos := back.position
        var size_value := back.size
        # A small anticipatory dip/tilt before the flip itself -- a card
        # that snaps straight to zero width reads as a UI wipe, not a card
        # physically turning over.
        var pre_flip := create_tween().set_parallel(true)
        pre_flip.tween_property(back, "scale:y", 1.05, 0.05).set_trans(Tween.TRANS_SINE)
        pre_flip.tween_property(back, "rotation", 0.03, 0.05)
        await pre_flip.finished
        play_pack_sfx("card_flip_whoosh", -3.0)
        var flip_out := create_tween().set_parallel(true)
        flip_out.tween_property(back, "scale:x", 0.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
        flip_out.tween_property(back, "scale:y", 0.94, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
        flip_out.tween_property(back, "rotation", 0.0, 0.14)
        await flip_out.finished
        if not is_instance_valid(back):
            continue
        var parent := back.get_parent()
        back.queue_free()
        if not is_instance_valid(parent):
            continue
        var cd: Dictionary = pulled[i]
        var rarity := str(cd.get("rarity", "Bronze"))
        var is_shiny_pull := bool(cd.get("is_shiny", false))
        play_pack_sfx(str(PACK_REVEAL_SFX.get(rarity, "draw")))
        pack_rarity_burst(pos + size_value / 2.0, "Shiny" if is_shiny_pull else rarity)
        var real := card_panel(cd, pos, size_value)
        real.pivot_offset = size_value / 2.0
        real.scale.x = 0.0
        parent.add_child(real)
        # A quick squash-on-landing after the flip settles -- selling actual
        # card weight instead of the flip stopping dead the instant it hits
        # full width.
        var flip_in := create_tween()
        flip_in.tween_property(real, "scale:x", 1.0, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        flip_in.tween_property(real, "scale", Vector2(1.05, 0.95), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        flip_in.tween_property(real, "scale", Vector2(1.0, 1.0), 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
        if rarity in ["Epic", "Legendary", "Platinum"] or is_shiny_pull:
            await flip_in.finished
            if not is_instance_valid(real):
                continue
            await _spotlight_reveal(real, "Shiny" if is_shiny_pull else rarity)

func _spotlight_reveal(real: Panel, rarity: String) -> void:
    # The single biggest lever for "feeling rewarded": Epic/Legendary/Platinum
    # pulls stop being a same-size card flip in a row of five and instead get
    # a dedicated moment — the screen dims, the card rises and grows center
    # stage, a rarity-colored title banner announces the pull, and a sparkle
    # burst fires, before the card settles back into its slot.
    var origin_position := real.position
    var origin_scale := real.scale
    var origin_parent := real.get_parent()
    var screen_center := Vector2(640.0, 300.0)
    var target_scale: Vector2 = Vector2(1.55, 1.55) if rarity == "Platinum" else (Vector2(1.4, 1.4) if rarity == "Legendary" else (Vector2(1.32, 1.32) if rarity == "Shiny" else Vector2(1.22, 1.22)))
    var target_position: Vector2 = screen_center - (real.size * target_scale) / 2.0

    var dimmer := ColorRect.new()
    dimmer.color = Color(0.01, 0.01, 0.03, 0.0)
    dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    dimmer.z_index = 300
    root_layer.add_child(dimmer)

    real.z_index = 320
    var glow_color := card_rarity_color(rarity)

    # Rotating light rays behind the card for the top two tiers -- the
    # dimmer + sparkles alone still read as "a card got bigger"; a slowly
    # spinning starburst gives Legendary/Platinum an actual radiant-altar
    # backdrop instead of just empty dimmed space.
    var rays: TextureRect = null
    if rarity in ["Legendary", "Platinum", "Shiny"]:
        var ray_gradient := Gradient.new()
        ray_gradient.colors = PackedColorArray([Color(glow_color.r, glow_color.g, glow_color.b, 0.0), Color(glow_color.r, glow_color.g, glow_color.b, 0.5), Color(glow_color.r, glow_color.g, glow_color.b, 0.0)])
        ray_gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
        var ray_tex := GradientTexture2D.new()
        ray_tex.gradient = ray_gradient
        ray_tex.fill = GradientTexture2D.FILL_RADIAL
        ray_tex.fill_from = Vector2(0.5, 0.5)
        ray_tex.fill_to = Vector2(1.0, 0.5)
        ray_tex.width = 640
        ray_tex.height = 640
        rays = TextureRect.new()
        rays.texture = ray_tex
        rays.position = screen_center - Vector2(320, 320)
        rays.size = Vector2(640, 640)
        rays.pivot_offset = Vector2(320, 320)
        rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
        rays.modulate.a = 0.0
        rays.z_index = 305
        root_layer.add_child(rays)
        var ray_spin := create_tween().set_loops().bind_node(rays)
        ray_spin.tween_property(rays, "rotation", TAU, 6.0 if rarity == "Legendary" else 4.5).as_relative().set_trans(Tween.TRANS_LINEAR)

    var title := Label.new()
    title.text = str(PACK_REVEAL_TITLE.get(rarity, "RARE PULL!"))
    title.position = Vector2(190, 90)
    title.size = Vector2(900, 70)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 46 if rarity == "Platinum" else 40)
    title.add_theme_color_override("font_color", glow_color)
    title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
    title.add_theme_constant_override("shadow_offset_x", 4)
    title.add_theme_constant_override("shadow_offset_y", 4)
    title.modulate.a = 0.0
    title.z_index = 330
    root_layer.add_child(title)

    # Sound design here is layered, not a single swapped cue: the base
    # rarity sound already played back in _animate_pack_reveal, and the top
    # two tiers get a distinct orchestral fanfare stacked on top of it right
    # as the card rises, so a Legendary/Platinum pull is audibly bigger than
    # just "a louder version of the same blip".
    if rarity == "Legendary" or rarity == "Shiny":
        play_pack_sfx("legendary_fanfare", -2.0)
    elif rarity == "Platinum":
        play_pack_sfx("platinum_fanfare")

    if rays != null:
        var rays_fade_in := create_tween()
        rays_fade_in.tween_property(rays, "modulate:a", 1.0, 0.28)

    var rise := create_tween().set_parallel(true)
    rise.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    rise.tween_property(dimmer, "color:a", 0.82, 0.22)
    rise.tween_property(real, "position", target_position, 0.32)
    rise.tween_property(real, "scale", target_scale, 0.32)
    rise.tween_property(title, "modulate:a", 1.0, 0.24)
    await rise.finished

    # A brief camera-shake punch, Platinum only -- the rarest possible pull
    # is the one moment worth shaking the whole screen for; doing this for
    # every rarity would make it feel routine instead of special.
    if rarity == "Platinum":
        var shake_origin := root_layer.position
        var cam_shake := create_tween()
        cam_shake.tween_property(root_layer, "position", shake_origin + Vector2(6, 4), 0.035)
        cam_shake.tween_property(root_layer, "position", shake_origin + Vector2(-7, -3), 0.035)
        cam_shake.tween_property(root_layer, "position", shake_origin + Vector2(5, -4), 0.035)
        cam_shake.tween_property(root_layer, "position", shake_origin + Vector2(-3, 3), 0.035)
        cam_shake.tween_property(root_layer, "position", shake_origin, 0.035)

    var sparkle_count := 24 if rarity == "Platinum" else (18 if rarity == "Legendary" else 12)
    spawn_reward_sparkles(screen_center, sparkle_count, [glow_color, Color(1, 1, 1)], 100.0)
    if rarity == "Platinum":
        # A second, wider sparkle wave a beat later so the platinum moment
        # doesn't peak and fade in one single burst.
        await get_tree().create_timer(0.18).timeout
        if is_instance_valid(real):
            spawn_reward_sparkles(screen_center, 16, [Color(1, 1, 1), glow_color], 150.0)

    var pop := create_tween()
    pop.tween_property(real, "scale", target_scale * 1.07, 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    pop.tween_property(real, "scale", target_scale, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    await pop.finished
    await get_tree().create_timer(0.55 if rarity == "Platinum" else 0.4).timeout

    if not is_instance_valid(real) or not is_instance_valid(origin_parent):
        dimmer.queue_free()
        title.queue_free()
        return
    var settle := create_tween().set_parallel(true)
    settle.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
    settle.tween_property(real, "position", origin_position, 0.26)
    settle.tween_property(real, "scale", origin_scale, 0.26)
    settle.tween_property(dimmer, "color:a", 0.0, 0.22)
    settle.tween_property(title, "modulate:a", 0.0, 0.18)
    if rays != null:
        settle.tween_property(rays, "modulate:a", 0.0, 0.22)
    await settle.finished
    if is_instance_valid(real):
        real.z_index = 0
    dimmer.queue_free()
    title.queue_free()
    if rays != null and is_instance_valid(rays):
        rays.queue_free()

# card_art_texture() removed — all callers now use CardArt.resolve(cd) directly.

func card_rarity_color(rarity: String) -> Color:
    if rarity == "Shiny":
        return Color(0.85, 0.62, 1.0)  # Holographic purple-white
    if rarity in ["Gold", "Signature Gold"]:
        return Color(1.0, 0.76, 0.20)
    elif rarity == "Epic":
        return Color(0.72, 0.38, 1.0)
    elif rarity == "Legendary":
        return Color(1.0, 0.42, 0.16)
    elif rarity == "Platinum":
        return Color(0.75, 0.95, 1.0)
    return Color(0.6, 0.66, 0.74)

func card_int_value(cd: Dictionary, field: String) -> int:
    # Card data sometimes stores numeric fields (cost/attack/health) as
    # floats, which used to print as "7.0" instead of "7" anywhere a card
    # was rendered in the menus — a small but very visible tell that these
    # were data labels slapped on a photo instead of a real card stat.
    return int(round(float(cd.get(field, 0))))

func card_panel(cd: Dictionary, pos: Vector2, size_value: Vector2, previewable := true) -> Panel:
    var p := Panel.new()
    p.position = pos
    p.size = size_value
    p.custom_minimum_size = size_value
    p.clip_contents = false

    var rarity := str(cd.get("rarity", "Bronze"))
    var border := class_color(str(cd.get("class", "Neutral")))
    if rarity not in ["Bronze", "Silver"]:
        border = card_rarity_color(rarity)

    # Rarity used to be readable only from the small "TYPE • RARITY" text
    # line below the stats -- two cards side by side looked identical at a
    # glance unless you actually read that line. A colored glow halo (the
    # same glow-by-rarity language CardView already uses for battle cards)
    # plus a diagonal foil sheen for the top two tiers now makes rarity
    # legible from across the grid, border color/text stay as a backup.
    var glow_color := Color(0, 0, 0, 0.55)
    var glow_size := 6
    var border_width := 3
    match rarity:
        "Silver":
            glow_color = Color(0.78, 0.88, 1.0, 0.35)
            glow_size = 9
        "Gold":
            glow_color = Color(1.0, 0.78, 0.24, 0.45)
            glow_size = 11
        "Epic":
            glow_color = Color(0.72, 0.38, 1.0, 0.50)
            glow_size = 12
        "Legendary":
            glow_color = Color(1.0, 0.5, 0.18, 0.55)
            glow_size = 14
            border_width = 4
        "Platinum":
            glow_color = Color(0.62, 0.92, 1.0, 0.60)
            glow_size = 16
            border_width = 4
        "Signature Gold":
            glow_color = Color(1.0, 0.85, 0.3, 0.60)
            glow_size = 16
            border_width = 4
        "Signature Platinum":
            glow_color = Color(0.7, 0.96, 1.0, 0.65)
            glow_size = 18
            border_width = 4

    var frame_style := StyleBoxFlat.new()
    frame_style.bg_color = Color(0.05, 0.045, 0.07, 1.0)
    frame_style.border_color = border
    frame_style.set_border_width_all(border_width)
    frame_style.set_corner_radius_all(12)
    frame_style.shadow_color = glow_color
    frame_style.shadow_size = glow_size
    p.add_theme_stylebox_override("panel", frame_style)

    # A slim inset highlight line reads as a stamped metal card edge instead
    # of a flat rectangle photo pasted on a background — the same two-tone
    # frame trick used by physical trading cards.
    var inner_frame := Panel.new()
    inner_frame.position = Vector2(4, 4)
    inner_frame.size = size_value - Vector2(8, 8)
    inner_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var inner_style := StyleBoxFlat.new()
    inner_style.bg_color = Color(0, 0, 0, 0)
    inner_style.border_color = Color(border.r, border.g, border.b, 0.55).lightened(0.3)
    inner_style.set_border_width_all(1)
    inner_style.set_corner_radius_all(9)
    inner_frame.add_theme_stylebox_override("panel", inner_style)
    p.add_child(inner_frame)

    var compact_panel := size_value.y < 230.0
    var pad := 8.0

    # A real, opaque name plate above the art — the single biggest thing
    # that used to make these read as "a photo with text stamped on it"
    # instead of a card: the name now lives in its own frame segment
    # instead of floating over a darkened patch of the artwork.
    var name_h: float = clampf(size_value.y * 0.14, 22.0, 34.0)
    var plate := Panel.new()
    plate.position = Vector2(pad, pad)
    plate.size = Vector2(size_value.x - pad * 2.0, name_h)
    plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var plate_style := StyleBoxFlat.new()
    plate_style.bg_color = Color(0.04, 0.045, 0.08, 0.95)
    plate_style.border_color = Color(border.r, border.g, border.b, 0.8)
    plate_style.border_width_bottom = 2
    plate_style.corner_radius_top_left = 8
    plate_style.corner_radius_top_right = 8
    plate.add_theme_stylebox_override("panel", plate_style)
    p.add_child(plate)
    var n := label(str(cd.get("name", "Card")), Vector2(4, 0), Vector2(size_value.x - pad * 2.0 - 8, name_h), 12 if compact_panel else 15, plate)
    n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    n.clip_text = true

    # The art sits in its own bordered window below the name plate instead
    # of bleeding edge-to-edge, like the picture frame on a real card.
    var art_top := pad + name_h + 4.0
    var art_height := size_value.y * (0.42 if compact_panel else 0.40)
    var art_frame := Panel.new()
    art_frame.position = Vector2(pad, art_top)
    art_frame.size = Vector2(size_value.x - pad * 2.0, art_height)
    art_frame.clip_contents = true
    var art_frame_style := StyleBoxFlat.new()
    art_frame_style.bg_color = Color(0, 0, 0, 1)
    art_frame_style.border_color = Color(border.r, border.g, border.b, 0.9)
    art_frame_style.set_border_width_all(2)
    art_frame_style.set_corner_radius_all(6)
    art_frame.add_theme_stylebox_override("panel", art_frame_style)
    p.add_child(art_frame)

    var art := TextureRect.new()
    art.texture = CardArt.resolve(cd)
    # Anchor to fill art_frame so layout resolves the size — no manual size calc.
    art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    art.offset_left   = 2
    art.offset_top    = 2
    art.offset_right  = -2
    art.offset_bottom = -2
    art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    art.mouse_filter = Control.MOUSE_FILTER_IGNORE
    art_frame.add_child(art)

    # Diagonal glass sheen — anchored to match the art rect exactly.
    var sheen := GradientTexture2D.new()
    var sheen_gradient := Gradient.new()
    sheen_gradient.colors = PackedColorArray([Color(1,1,1,0.18), Color(1,1,1,0.0)])
    sheen_gradient.offsets = PackedFloat32Array([0.0, 1.0])
    sheen.gradient = sheen_gradient
    sheen.fill_from = Vector2(0.05, 0.0)
    sheen.fill_to = Vector2(0.6, 0.75)
    var sheen_rect := TextureRect.new()
    sheen_rect.texture = sheen
    sheen_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    sheen_rect.offset_left   = 2
    sheen_rect.offset_top    = 2
    sheen_rect.offset_right  = -2
    sheen_rect.offset_bottom = -2
    sheen_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    art_frame.add_child(sheen_rect)

    # A second, card-wide diagonal foil band (beyond the plain art sheen
    # above) is what actually sells "foil card" for the top rarity tiers --
    # tinted with the same glow color as the halo so the whole card reads
    # as one coherent premium treatment instead of a glow plus an unrelated
    # sheen.
    if rarity in ["Legendary", "Platinum", "Signature Gold", "Signature Platinum"]:
        var foil_gradient := Gradient.new()
        foil_gradient.colors = PackedColorArray([
            Color(glow_color.r, glow_color.g, glow_color.b, 0.0),
            Color(1.0, 1.0, 1.0, 0.32),
            Color(glow_color.r, glow_color.g, glow_color.b, 0.0),
        ])
        foil_gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
        var foil_tex := GradientTexture2D.new()
        foil_tex.gradient = foil_gradient
        foil_tex.fill_from = Vector2(0.1, 0.0)
        foil_tex.fill_to = Vector2(0.75, 1.0)
        var foil_rect := TextureRect.new()
        foil_rect.texture = foil_tex
        foil_rect.position = Vector2.ZERO
        foil_rect.size = size_value
        foil_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
        foil_rect.z_index = 1
        p.add_child(foil_rect)

    # A circular cost gem stamped over the plate/art seam, exactly where a
    # real card's mana/cost icon would sit — not a bare number floating on
    # top of the artwork with nothing framing it.
    var cost_gem := Panel.new()
    var gem_size := 30.0 if compact_panel else 36.0
    cost_gem.position = Vector2(pad - gem_size * 0.32, art_top - gem_size * 0.5)
    cost_gem.size = Vector2(gem_size, gem_size)
    var gem_style := StyleBoxFlat.new()
    gem_style.bg_color = Color(0.16, 0.5, 0.92)
    gem_style.border_color = Color(0.9, 0.95, 1.0)
    gem_style.set_border_width_all(2)
    gem_style.set_corner_radius_all(int(gem_size / 2.0))
    gem_style.shadow_color = Color(0, 0, 0, 0.5)
    gem_style.shadow_size = 3
    cost_gem.add_theme_stylebox_override("panel", gem_style)
    cost_gem.z_index = 5
    p.add_child(cost_gem)
    var cost_label := label(str(card_int_value(cd, "cost")), Vector2(0, 0), Vector2(gem_size, gem_size), 15 if compact_panel else 18, cost_gem)
    cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    cost_label.add_theme_color_override("font_color", Color.WHITE)

    var stats_y := art_top + art_height + 6.0
    var is_amulet := bool(cd.get("is_amulet", false))
    var is_spell := bool(cd.get("is_spell", false))
    # A card's TYPE (Follower/Spell/Amulet) was previously only implied --
    # amulets got an "AMULET" stamp, but spells silently fell into the same
    # branch as followers and showed a meaningless 0/0 attack-health line
    # instead of anything indicating they were spells. Every card now gets
    # an explicit, correct type word players can read at a glance.
    var type_str := "AMULET" if is_amulet else ("SPELL" if is_spell else "FOLLOWER")
    if is_amulet:
        var amulet_label := label("AMULET", Vector2(9, stats_y), Vector2(size_value.x - 18, 22), 13 if compact_panel else 15, p)
        amulet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        amulet_label.add_theme_color_override("font_color", GOLD_COLOR)
    elif is_spell:
        var spell_label := label("SPELL", Vector2(9, stats_y), Vector2(size_value.x - 18, 22), 13 if compact_panel else 15, p)
        spell_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        spell_label.add_theme_color_override("font_color", Color(0.72, 0.62, 1.0))
    else:
        var sword := label("⚔", Vector2(pad + 6, stats_y), Vector2(24, 22), 14 if compact_panel else 16, p)
        var stats_text := "%d     %d" % [card_int_value(cd, "attack"), card_int_value(cd, "health")]
        var st := label(stats_text, Vector2(9, stats_y), Vector2(size_value.x - 18, 22), 13 if compact_panel else 16, p)
        st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        var heart := label("♥", Vector2(size_value.x - pad - 30, stats_y), Vector2(24, 22), 14 if compact_panel else 16, p)
        heart.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        heart.add_theme_color_override("font_color", Color(1.0, 0.4, 0.42))

    # Cost is already shown in the gem stamped on the art; this line now
    # reads "TYPE • RARITY" (e.g. "FOLLOWER • BRONZE") instead of rarity
    # alone, so cost, type, and rarity are all visible on every card tile.
    var rarity_y := stats_y + 22.0
    var r := label("%s  •  %s" % [type_str, rarity.to_upper()], Vector2(9, rarity_y), Vector2(size_value.x - 18, 18), 9 if compact_panel else 11, p)
    r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    r.add_theme_color_override("font_color", border)

    if not compact_panel:
        var divider := ColorRect.new()
        divider.color = Color(border.r, border.g, border.b, 0.35)
        divider.position = Vector2(pad, rarity_y + 20.0)
        divider.size = Vector2(size_value.x - pad * 2.0, 1)
        divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
        p.add_child(divider)

        var effect_y := rarity_y + 26.0
        var effect := label(str(cd.get("effect", "")), Vector2(11, effect_y), Vector2(size_value.x - 22, size_value.y - effect_y - 9), 11, p)
        effect.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        effect.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

    # A duplicate pull (already owned at its copy limit, silently converted
    # to Vials by add_card_to_collection) must never look identical to a
    # brand-new card in the reveal/results screens -- stamp a badge over the
    # art whenever the caller tagged this card dict with _dup_info. Card
    # dicts everywhere else (collection, deck builder, previews) never carry
    # this key, so the badge only ever appears on actual pack pulls.
    var dup_info: Dictionary = cd.get("_dup_info", {})
    if bool(dup_info.get("is_duplicate", false)):
        var dup_badge := Panel.new()
        var dup_badge_h: float = clampf(size_value.y * 0.16, 20.0, 30.0)
        dup_badge.position = Vector2(art_frame.position.x, art_frame.position.y + art_frame.size.y - dup_badge_h)
        dup_badge.size = Vector2(art_frame.size.x, dup_badge_h)
        dup_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
        dup_badge.z_index = 25
        var dup_style := StyleBoxFlat.new()
        dup_style.bg_color = Color(0.1, 0.03, 0.16, 0.92)
        dup_style.border_color = Color(0.78, 0.5, 1.0, 0.95)
        dup_style.set_border_width_all(2)
        dup_style.set_corner_radius_all(0)
        dup_badge.add_theme_stylebox_override("panel", dup_style)
        p.add_child(dup_badge)
        var dup_label := label("DUPLICATE +%d VIALS" % int(dup_info.get("vials", 0)), Vector2(0, 0), dup_badge.size, 9 if compact_panel else 11, dup_badge)
        dup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        dup_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        dup_label.add_theme_color_override("font_color", Color(0.92, 0.82, 1.0))

    if previewable:
        var tap_catcher := Button.new()
        tap_catcher.flat = true
        tap_catcher.focus_mode = Control.FOCUS_NONE
        tap_catcher.position = Vector2.ZERO
        tap_catcher.size = size_value
        tap_catcher.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
        tap_catcher.tooltip_text = "Tap to inspect this card"
        tap_catcher.pressed.connect(show_card_preview.bind(cd))
        p.add_child(tap_catcher)

    # Shiny ownership badge — a small ✦ N in the top-right corner so players
    # can see at a glance which cards they own shiny copies of while browsing
    # collection or crafting screens. Only added to non-shiny panels; a shiny
    # card panel already renders with the rainbow foil, so the badge is
    # redundant and visually noisy on top of that effect.
    if not bool(cd.get("is_shiny", false)):
        var _shiny_count := int(collection_shiny_owned.get(str(cd.get("id", "")), 0))
        if _shiny_count > 0:
            var _badge := Label.new()
            _badge.text = "✦ %d" % _shiny_count
            _badge.position = Vector2(4, 4)
            _badge.size = Vector2(size_value.x - 8, 20)
            _badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
            _badge.add_theme_font_size_override("font_size", 12)
            _badge.add_theme_color_override("font_color", Color(0.88, 0.65, 1.0))
            _badge.add_theme_color_override("font_shadow_color", Color.BLACK)
            _badge.add_theme_constant_override("shadow_offset_x", 1)
            _badge.add_theme_constant_override("shadow_offset_y", 1)
            _badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
            _badge.z_index = 50
            p.add_child(_badge)

    return p

func show_card_preview(cd: Dictionary) -> void:
    # Full-size read-only inspection popup so players can check a card's
    # exact wording and stats from the deck builder or collection grid
    # without it being confused for a playable/drag target.
    var scrim := ColorRect.new()
    scrim.color = Color(0.02, 0.03, 0.06, 0.82)
    scrim.position = Vector2.ZERO
    scrim.size = Vector2(1280, 720)
    scrim.mouse_filter = Control.MOUSE_FILTER_STOP
    scrim.z_index = 900
    scrim.gui_input.connect(func(event):
        if event is InputEventMouseButton and event.pressed:
            scrim.queue_free()
    )
    root_layer.add_child(scrim)

    var rarity := str(cd.get("rarity", "Bronze"))
    var border := class_color(str(cd.get("class", "Neutral")))
    if rarity in ["Gold", "Signature Gold"]:
        border = Color(1.0, 0.76, 0.20)
    elif rarity == "Epic":
        border = Color(0.72, 0.38, 1.0)
    elif rarity == "Legendary":
        border = Color(1.0, 0.42, 0.16)
    elif rarity == "Platinum":
        border = Color(0.75, 0.95, 1.0)

    var big_card := card_panel(cd, Vector2(490, 40), Vector2(300, 460), false)
    big_card.z_index = 901
    scrim.add_child(big_card)

    # Parent directly to scrim instead of the label()/centered_label() default
    # of root_layer — calling add_child() on a node that already has a parent
    # is a no-op error in Godot, which was silently leaving this caption
    # detached from the popup (and, depending on draw order, invisible).
    var preview_type_str := "AMULET" if bool(cd.get("is_amulet", false)) else ("SPELL" if bool(cd.get("is_spell", false)) else "FOLLOWER")
    var caption := label("%s  •  %s  •  %s" % [str(cd.get("class", "Neutral")).to_upper(), preview_type_str, rarity.to_upper()], Vector2(390, 520), Vector2(500, 30), 16, scrim)
    caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    caption.add_theme_color_override("font_color", border)
    caption.z_index = 901

    var close_btn := button("CLOSE", Vector2(560, 570), Vector2(160, 48), scrim.queue_free, scrim)
    close_btn.z_index = 901

func _collection_set_class_filter(c: String) -> void:
    collection_filter_class = c
    show_collection()

func _collection_set_rarity_filter(r: String) -> void:
    collection_filter_rarity = r
    show_collection()

func _collection_set_missing_only(v: bool) -> void:
    collection_missing_only = v
    show_collection()

func show_craft_screen() -> void:
    # Direct shortcut from pack results ("I just got Vials, now what?") into
    # a collection view pre-filtered to what those Vials can actually buy --
    # clearing class/rarity/search filters so a missing card never hides
    # behind whatever filter was left set from a previous visit.
    collection_filter_class = "All"
    collection_filter_rarity = "All"
    collection_search_query = ""
    collection_missing_only = true
    show_collection()

func _collection_set_search(text: String) -> void:
    collection_search_query = text
    _collection_focus_search_next = true
    show_collection()

func show_collection() -> void:
    clear_screen(); add_background(0.82)
    header("COLLECTION & CRAFTING", "Showing cards you're missing" if collection_missing_only else "Craft any card from any class • Deck class only matters when building")

    # ── Row 1 (y=106-148): Craft-cost guide (left) + currency panel (right) ──
    # currency_bar() is NOT called here — its hard-coded position overlaps the
    # guide label. Instead both live on the same row in non-overlapping x-ranges.
    var guide := label(
        "CREATE:  Bronze 50  •  Silver 150  •  Gold 500  •  Epic 2,500  •  Legendary 3,500  •  Platinum 4,500",
        Vector2(24, 112), Vector2(818, 28), 14)
    guide.add_theme_color_override("font_color", Color(0.78, 0.90, 1.0))

    var cur_panel := Panel.new()
    cur_panel.position = Vector2(848, 106)
    cur_panel.size = Vector2(428, 40)
    cur_panel.add_theme_stylebox_override("panel", style(Color(0.32, 0.72, 0.95)))
    root_layer.add_child(cur_panel)
    var cur_lbl := label(
        "GOLD %d   •   VIALS %d   •   PACKS %d" % [gold_balance, dust_balance, pack_inventory],
        Vector2(6, 8), Vector2(416, 24), 15, cur_panel)
    cur_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

    # ── Row 2 (y=150-172): Ownership summary ─────────────────────────────────
    var filtered_preview: Array = _collection_filtered_sorted_cards()
    var owned_count := 0
    for cd in filtered_preview:
        if int(collection_owned.get(str(cd["id"]), 0)) > 0:
            owned_count += 1
    var summary := label(
        "Showing %d/%d cards  •  %d owned in this view" % [filtered_preview.size(), cards.size(), owned_count],
        Vector2(24, 150), Vector2(1232, 22), 13)
    summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    summary.add_theme_color_override("font_color", Color(0.6, 0.66, 0.78))

    # ── Row 3 (y=176-208): Search box + Missing Only toggle ───────────────────
    var search_box := LineEdit.new()
    search_box.position = Vector2(24, 176)
    search_box.size = Vector2(548, 30)
    search_box.placeholder_text = "Search by name or keyword..."
    search_box.text = collection_search_query
    search_box.add_theme_font_size_override("font_size", 14)
    search_box.text_changed.connect(_collection_set_search)
    root_layer.add_child(search_box)
    if not collection_search_query.is_empty():
        var clear_search := button("✕", Vector2(580, 176), Vector2(30, 30), _collection_set_search.bind(""))
        clear_search.add_theme_font_size_override("font_size", 12)
    if _collection_focus_search_next:
        search_box.grab_focus()
        search_box.caret_column = search_box.text.length()
        _collection_focus_search_next = false

    var missing_toggle := button(
        "✓ MISSING ONLY" if collection_missing_only else "MISSING ONLY",
        Vector2(624, 176), Vector2(188, 30),
        _collection_set_missing_only.bind(not collection_missing_only)
    )
    missing_toggle.add_theme_font_size_override("font_size", 12)
    if collection_missing_only:
        missing_toggle.add_theme_stylebox_override("normal", solid_style(GOLD_COLOR, 6))
        missing_toggle.add_theme_stylebox_override("hover", solid_style(GOLD_COLOR.lightened(0.15), 6))
        missing_toggle.add_theme_color_override("font_color", Color(0.08, 0.06, 0.02))
        missing_toggle.add_theme_color_override("font_hover_color", Color(0.08, 0.06, 0.02))

    # ── Row 4 (y=212-248): Class filter tabs — uniform height & spacing ────────
    var class_tabs := ["All"] + CLASSES + ["Neutral"]
    var tab_w: float = 1232.0 / float(class_tabs.size())
    for i in range(class_tabs.size()):
        var c: String = class_tabs[i]
        var tab_btn := button(c.to_upper(), Vector2(24 + i * tab_w, 212), Vector2(tab_w - 6, 34), _collection_set_class_filter.bind(c))
        if c == collection_filter_class:
            tab_btn.add_theme_stylebox_override("normal", solid_style(GOLD_COLOR, 8))
            tab_btn.add_theme_stylebox_override("hover", solid_style(GOLD_COLOR.lightened(0.15), 8))
            tab_btn.add_theme_color_override("font_color", Color(0.08, 0.06, 0.02))
            tab_btn.add_theme_color_override("font_hover_color", Color(0.08, 0.06, 0.02))

    # ── Row 5 (y=252-284): Rarity filter tabs — only present rarities ─────────
    var rarity_order := ["Bronze", "Silver", "Gold", "Epic", "Legendary", "Platinum", "Signature Gold", "Signature Platinum"]
    var present_rarities: Array = []
    for cd in cards:
        var r := str(cd.get("rarity", "Bronze"))
        if r not in present_rarities:
            present_rarities.append(r)
    present_rarities.sort_custom(func(a, b): return rarity_order.find(a) < rarity_order.find(b))
    var rarity_tabs := ["All"] + present_rarities
    var rtab_w: float = 1232.0 / float(rarity_tabs.size())
    for i in range(rarity_tabs.size()):
        var r: String = rarity_tabs[i]
        var rtab_btn := button(r.to_upper(), Vector2(24 + i * rtab_w, 252), Vector2(rtab_w - 6, 30), _collection_set_rarity_filter.bind(r))
        rtab_btn.add_theme_font_size_override("font_size", 11)
        if r == collection_filter_rarity:
            rtab_btn.add_theme_stylebox_override("normal", solid_style(GOLD_COLOR, 6))
            rtab_btn.add_theme_stylebox_override("hover", solid_style(GOLD_COLOR.lightened(0.15), 6))
            rtab_btn.add_theme_color_override("font_color", Color(0.08, 0.06, 0.02))
            rtab_btn.add_theme_color_override("font_hover_color", Color(0.08, 0.06, 0.02))

    # ── Card binder (y=288 → bottom) — more vertical room than before ─────────
    var binder := Panel.new()
    binder.position = Vector2(24, 288)
    binder.size = Vector2(1232, 424)
    var binder_style := StyleBoxFlat.new()
    binder_style.bg_color = Color(0.01, 0.02, 0.045, 0.78)
    binder_style.border_color = GOLD_COLOR
    binder_style.set_border_width_all(2)
    binder_style.corner_radius_top_left = 14
    binder_style.corner_radius_top_right = 14
    binder_style.corner_radius_bottom_left = 14
    binder_style.corner_radius_bottom_right = 14
    binder.add_theme_stylebox_override("panel", binder_style)
    root_layer.add_child(binder)
    var scroll := ScrollContainer.new()
    scroll.position = Vector2(10, 10)
    scroll.size = Vector2(1212, 404)
    binder.add_child(scroll)
    if filtered_preview.is_empty():
        centered_label("No cards match this filter.", Vector2(0, 180), Vector2(1212, 30), 16, scroll)
        return
    var grid := GridContainer.new()
    grid.columns = 6
    grid.add_theme_constant_override("h_separation", 20)
    grid.add_theme_constant_override("v_separation", 20)
    scroll.add_child(grid)
    for cd in filtered_preview:
        var id := str(cd["id"])
        var rarity := str(cd["rarity"])
        var owned := int(collection_owned.get(id, 0))
        var limit := int(COPY_LIMITS.get(rarity, 1))
        var wrap := VBoxContainer.new()
        wrap.custom_minimum_size = Vector2(182, 352)
        var cp := card_panel(cd, Vector2.ZERO, Vector2(178, 248))
        wrap.add_child(cp)
        if owned <= 0:
            cp.modulate = Color(0.48, 0.52, 0.60, 0.90)
            var lock_badge := Label.new()
            lock_badge.text = "LOCKED"
            lock_badge.position = Vector2(36, 102)
            lock_badge.size = Vector2(106, 30)
            lock_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
            lock_badge.add_theme_font_size_override("font_size", 12)
            lock_badge.add_theme_color_override("font_color", Color.WHITE)
            lock_badge.add_theme_color_override("font_shadow_color", Color.BLACK)
            lock_badge.add_theme_constant_override("shadow_offset_x", 2)
            lock_badge.add_theme_constant_override("shadow_offset_y", 2)
            lock_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
            cp.add_child(lock_badge)
        var own := label("Owned %d/%d" % [owned, limit], Vector2.ZERO, Vector2(178, 22), 13, wrap)
        own.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        if rarity in ["Bronze", "Silver"]:
            var vial := Button.new()
            vial.text = "VIAL +%d" % int(DUST_VALUES.get(rarity, 0))
            vial.disabled = owned <= count_in_deck(id)
            vial.tooltip_text = "Copies currently used in your saved deck are protected."
            vial.pressed.connect(dust_card.bind(id))
            wrap.add_child(vial)
        elif rarity in ["Gold", "Epic", "Legendary"]:
            var auto_note := label("Extras auto-vial", Vector2.ZERO, Vector2(178, 18), 11, wrap)
            auto_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
            auto_note.add_theme_color_override("font_color", Color(0.6, 0.66, 0.78))
        else:
            var protected_note := label("Signature — pack only", Vector2.ZERO, Vector2(178, 18), 11, wrap)
            protected_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
            protected_note.add_theme_color_override("font_color", Color(0.6, 0.66, 0.78))
        if CRAFT_COSTS.has(rarity):
            var craft := Button.new()
            var cost := int(CRAFT_COSTS[rarity])
            craft.text = "CREATE %s" % _fmt_vial_cost(cost)
            craft.disabled = owned >= limit or dust_balance < cost
            craft.pressed.connect(craft_card.bind(id))
            wrap.add_child(craft)
        grid.add_child(wrap)

func _fmt_vial_cost(n: int) -> String:
    return "%d,%03d" % [n / 1000, n % 1000] if n >= 1000 else "%d" % n

func _collection_filtered_sorted_cards() -> Array:
    var out: Array = []
    var query := collection_search_query.strip_edges().to_lower()
    for cd in cards:
        var card_class := str(cd.get("class", "Neutral"))
        if collection_filter_class != "All" and card_class != collection_filter_class:
            continue
        if collection_filter_rarity != "All" and str(cd.get("rarity", "")) != collection_filter_rarity:
            continue
        if collection_missing_only:
            var owned_count := int(collection_owned.get(str(cd["id"]), 0))
            var copy_limit := int(COPY_LIMITS.get(str(cd.get("rarity", "Bronze")), 1))
            if owned_count >= copy_limit:
                continue
        if not query.is_empty():
            var name_match := str(cd.get("name", "")).to_lower().contains(query)
            var effect_match := str(cd.get("effect", "")).to_lower().contains(query)
            if not name_match and not effect_match:
                continue
        out.append(cd)
    var rarity_order := ["Bronze", "Silver", "Gold", "Epic", "Legendary", "Platinum", "Signature Gold", "Signature Platinum"]
    out.sort_custom(func(a: Dictionary, b: Dictionary):
        var ca := str(a.get("class", "Neutral"))
        var cb := str(b.get("class", "Neutral"))
        if ca != cb:
            return ca < cb
        var ra := rarity_order.find(str(a.get("rarity", "Bronze")))
        var rb := rarity_order.find(str(b.get("rarity", "Bronze")))
        if ra != rb:
            return ra < rb
        var costa := int(a.get("cost", 0))
        var costb := int(b.get("cost", 0))
        if costa != costb:
            return costa < costb
        return str(a.get("name", "")) < str(b.get("name", ""))
    )
    return out

func dust_card(id: String) -> void:
    var cd := card_by_id(id)
    if cd.is_empty():
        return
    var rarity := str(cd.get("rarity", "Bronze"))
    if rarity not in ["Bronze", "Silver"]:
        return
    var owned := int(collection_owned.get(id, 0))
    # Never dismantle a copy currently required by the active saved deck.
    if owned <= count_in_deck(id):
        return
    collection_owned[id] = owned - 1
    dust_balance += int(DUST_VALUES.get(rarity, 0))
    save_profile()
    show_collection()

func craft_card(id: String) -> void:
    var cd := card_by_id(id)
    if cd.is_empty():
        return
    var rarity := str(cd.get("rarity", "Bronze"))
    if not CRAFT_COSTS.has(rarity):
        return
    var cost := int(CRAFT_COSTS[rarity])
    var owned := int(collection_owned.get(id, 0))
    var limit := int(COPY_LIMITS.get(rarity, 1))
    if owned >= limit or dust_balance < cost:
        return
    dust_balance -= cost
    collection_owned[id] = owned + 1
    save_profile()
    show_collection()

func switch_deck_class(c: String) -> void:
    # Preserve each class deck independently so players can build every class.
    saved_decks[selected_deck_class] = saved_deck.duplicate()
    selected_deck_class = c
    saved_deck = Array(saved_decks.get(c, []))
    save_profile()
    show_deck_builder()

func show_deck_preview() -> void:
    # Read-only view of the currently active class's saved deck, reachable
    # straight from the home screen without entering the full deck builder.
    # Tapping any card still opens the same full-detail inspector.
    clear_screen(); add_background(0.82)
    var active_class := selected_class if selected_class != "" else "Hope"
    header("DECK PREVIEW — " + active_class.to_upper(), "Tap any card to inspect it • Go to DECKS to add or remove cards")
    var deck: Array = Array(saved_decks.get(active_class, []))
    if deck.is_empty():
        centered_label("This deck is empty.", Vector2(340, 260), Vector2(600, 40), 22).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        centered_label("Visit DECKS from the home screen to add cards.", Vector2(340, 310), Vector2(600, 30), 15)
        button("BACK", Vector2(540, 400), Vector2(200, 54), show_home)
        return
    var counts: Dictionary = {}
    for id in deck:
        counts[str(id)] = int(counts.get(str(id), 0)) + 1
    var binder := Panel.new()
    binder.position = Vector2(28, 176); binder.size = Vector2(1224, 470)
    var binder_style := StyleBoxFlat.new()
    binder_style.bg_color = Color(0.01, 0.02, 0.045, 0.78)
    binder_style.border_color = GOLD_COLOR
    binder_style.set_border_width_all(2)
    binder_style.set_corner_radius_all(14)
    binder.add_theme_stylebox_override("panel", binder_style)
    root_layer.add_child(binder)
    var scroll := ScrollContainer.new(); scroll.position = Vector2(12, 12); scroll.size = Vector2(1200, 446); binder.add_child(scroll)
    var grid := GridContainer.new(); grid.columns = 7
    grid.add_theme_constant_override("h_separation", 14); grid.add_theme_constant_override("v_separation", 16)
    scroll.add_child(grid)
    var seen: Dictionary = {}
    for id in deck:
        var sid := str(id)
        if seen.has(sid):
            continue
        seen[sid] = true
        var cd := card_by_id(sid)
        if cd.is_empty():
            continue
        var wrap := VBoxContainer.new(); wrap.custom_minimum_size = Vector2(156, 245)
        var cp := card_panel(cd, Vector2.ZERO, Vector2(150, 214))
        wrap.add_child(cp)
        var count_label := Label.new()
        count_label.text = "Copies: %d" % int(counts.get(sid, 1))
        count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        count_label.add_theme_font_size_override("font_size", 12)
        wrap.add_child(count_label)
        grid.add_child(wrap)
    button("BACK TO HOME", Vector2(28, 656), Vector2(220, 48), show_home)
    button("EDIT THIS DECK", Vector2(264, 656), Vector2(220, 48), show_deck_builder)

func show_deck_builder() -> void:
    clear_screen()

    # Full-screen dark background — no battle UI visible behind it
    var bg := ColorRect.new()
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg.color = Color(0.030, 0.035, 0.058, 1.0)
    bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root_layer.add_child(bg)

    if selected_class == "":
        var prompt_vb := VBoxContainer.new()
        prompt_vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        prompt_vb.alignment = BoxContainer.ALIGNMENT_CENTER
        prompt_vb.add_theme_constant_override("separation", 16)
        root_layer.add_child(prompt_vb)
        var pl := Label.new(); pl.text = "CHOOSE A CLASS FIRST"
        pl.add_theme_font_size_override("font_size", 30)
        pl.add_theme_color_override("font_color", GOLD_COLOR)
        pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; prompt_vb.add_child(pl)
        var pl2 := Label.new()
        pl2.text = "Your class unlocks a starter deck. Pack pulls can then be added here."
        pl2.add_theme_font_size_override("font_size", 16)
        pl2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; prompt_vb.add_child(pl2)
        var pb := Button.new(); pb.text = "CHOOSE MY CLASS"
        pb.custom_minimum_size = Vector2(280, 56); pb.add_theme_font_size_override("font_size", 18)
        pb.add_theme_stylebox_override("normal", style(GOLD_COLOR, 10))
        pb.pressed.connect(show_class_choice); prompt_vb.add_child(pb)
        return

    # Root layout: vertical stack
    var root_vbox := VBoxContainer.new()
    root_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root_vbox.add_theme_constant_override("separation", 0)
    root_layer.add_child(root_vbox)

    _build_db_header(root_vbox)

    var content := HBoxContainer.new()
    content.size_flags_vertical = Control.SIZE_FILL | Control.SIZE_EXPAND
    content.add_theme_constant_override("separation", 0)
    root_vbox.add_child(content)

    _build_db_filter_column(content)
    _build_db_card_grid(content)
    _build_db_deck_panel(content)

func _build_db_header(parent: Control) -> void:
    var hp := Panel.new()
    hp.custom_minimum_size = Vector2(0, 72)
    hp.size_flags_horizontal = Control.SIZE_FILL
    var hs := StyleBoxFlat.new()
    hs.bg_color = Color(0.018, 0.022, 0.040, 1.0)
    hs.border_color = Color(0.22, 0.17, 0.07)
    hs.set_border_width_all(0); hs.border_width_bottom = 2
    hp.add_theme_stylebox_override("panel", hs)
    parent.add_child(hp)

    var back := Button.new()
    back.text = "BACK"
    back.position = Vector2(12, 16); back.size = Vector2(110, 40)
    back.add_theme_font_size_override("font_size", 14)
    back.add_theme_stylebox_override("normal", style(Color(0.55, 0.45, 0.22), 8))
    back.add_theme_stylebox_override("hover", style(GOLD_COLOR, 8))
    back.pressed.connect(func():
        save_profile()
        editing_deck_slot_idx = -1
        show_deck_manager())
    hp.add_child(back)

    var title := Label.new()
    title.text = "DECK BUILDER"
    title.add_theme_font_size_override("font_size", 24)
    title.add_theme_color_override("font_color", GOLD_COLOR)
    title.position = Vector2(138, 8); title.size = Vector2(300, 32)
    hp.add_child(title)

    var deck_name := "Select a deck slot"
    if editing_deck_slot_idx >= 0 and editing_deck_slot_idx < deck_slots.size():
        deck_name = str(deck_slots[editing_deck_slot_idx].get("name", "Deck %d" % (editing_deck_slot_idx + 1)))
    var sub := Label.new()
    sub.text = "%s  |  40 cards  |  Class + Neutral  |  Copy limits apply" % deck_name
    sub.add_theme_font_size_override("font_size", 12)
    sub.add_theme_color_override("font_color", Color(0.62, 0.62, 0.74))
    sub.position = Vector2(138, 44); sub.size = Vector2(600, 22)
    hp.add_child(sub)

    var curr := Label.new()
    curr.text = "GOLD %d  |  VIALS %d  |  PACKS %d" % [gold_balance, dust_balance, pack_inventory]
    curr.add_theme_font_size_override("font_size", 14)
    curr.add_theme_color_override("font_color", Color(0.85, 0.72, 0.35))
    curr.position = Vector2(756, 22); curr.size = Vector2(510, 28)
    curr.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    hp.add_child(curr)

func _db_sep(parent: Control) -> void:
    var sep := HSeparator.new()
    var ss := StyleBoxFlat.new()
    ss.bg_color = Color(0.18, 0.18, 0.28, 0.40)
    sep.add_theme_stylebox_override("separator", ss)
    parent.add_child(sep)

func _build_db_filter_column(parent: Control) -> void:
    var pc := PanelContainer.new()
    pc.custom_minimum_size = Vector2(210, 0)
    pc.size_flags_vertical = Control.SIZE_FILL
    var ps := StyleBoxFlat.new()
    ps.bg_color = Color(0.024, 0.030, 0.050, 1.0)
    ps.border_color = Color(0.12, 0.10, 0.05)
    ps.set_border_width_all(0); ps.border_width_right = 1
    pc.add_theme_stylebox_override("panel", ps)
    parent.add_child(pc)

    var mc := MarginContainer.new()
    mc.add_theme_constant_override("margin_left", 10)
    mc.add_theme_constant_override("margin_right", 10)
    mc.add_theme_constant_override("margin_top", 10)
    mc.add_theme_constant_override("margin_bottom", 10)
    pc.add_child(mc)

    var vb := VBoxContainer.new()
    vb.add_theme_constant_override("separation", 8)
    vb.size_flags_vertical = Control.SIZE_FILL
    mc.add_child(vb)

    # Header row
    var fhdr := HBoxContainer.new(); vb.add_child(fhdr)
    var fhdr_lbl := Label.new(); fhdr_lbl.text = "FILTERS"
    fhdr_lbl.add_theme_font_size_override("font_size", 14)
    fhdr_lbl.add_theme_color_override("font_color", GOLD_COLOR)
    fhdr_lbl.size_flags_horizontal = Control.SIZE_FILL | Control.SIZE_EXPAND
    fhdr.add_child(fhdr_lbl)
    var clear_btn := Button.new(); clear_btn.text = "X CLEAR"
    clear_btn.add_theme_font_size_override("font_size", 11)
    clear_btn.custom_minimum_size = Vector2(60, 24)
    clear_btn.add_theme_stylebox_override("normal", style(Color(0.45, 0.28, 0.18), 5))
    clear_btn.pressed.connect(func():
        _db_owned_only = false; _db_cost_filter = -1
        _db_rarity_filter = ""; _db_type_filter = ""; _db_search_text = ""
        show_deck_builder())
    fhdr.add_child(clear_btn)

    _db_sep(vb)

    # Search
    var srch_lbl := Label.new(); srch_lbl.text = "SEARCH"
    srch_lbl.add_theme_font_size_override("font_size", 11)
    srch_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.68))
    vb.add_child(srch_lbl)
    var srch_row := HBoxContainer.new()
    srch_row.add_theme_constant_override("separation", 4)
    vb.add_child(srch_row)
    var search_field := LineEdit.new()
    search_field.placeholder_text = "Card name..."
    search_field.text = _db_search_text
    search_field.add_theme_font_size_override("font_size", 13)
    search_field.custom_minimum_size = Vector2(0, 30)
    search_field.size_flags_horizontal = Control.SIZE_FILL | Control.SIZE_EXPAND
    srch_row.add_child(search_field)
    var srch_go := Button.new(); srch_go.text = "GO"
    srch_go.custom_minimum_size = Vector2(30, 30)
    srch_go.add_theme_font_size_override("font_size", 12)
    srch_go.add_theme_stylebox_override("normal", style(Color(0.35, 0.45, 0.62), 6))
    srch_go.pressed.connect(func(): _db_search_text = search_field.text; show_deck_builder())
    srch_row.add_child(srch_go)
    search_field.text_submitted.connect(func(txt: String): _db_search_text = txt; show_deck_builder())

    _db_sep(vb)

    # Class tabs
    var cls_lbl := Label.new(); cls_lbl.text = "CLASS"
    cls_lbl.add_theme_font_size_override("font_size", 11)
    cls_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.68))
    vb.add_child(cls_lbl)
    if editing_deck_slot_idx >= 0:
        var fixed_lbl := Label.new()
        fixed_lbl.text = selected_deck_class.to_upper() + " (locked)"
        fixed_lbl.add_theme_font_size_override("font_size", 13)
        fixed_lbl.add_theme_color_override("font_color", class_color(selected_deck_class).lightened(0.25))
        vb.add_child(fixed_lbl)
    else:
        var cls_grid := GridContainer.new(); cls_grid.columns = 2
        cls_grid.add_theme_constant_override("h_separation", 4)
        cls_grid.add_theme_constant_override("v_separation", 4)
        vb.add_child(cls_grid)
        for c in CLASSES:
            var cb := Button.new(); cb.text = str(c)
            cb.add_theme_font_size_override("font_size", 12)
            cb.custom_minimum_size = Vector2(82, 30)
            if str(c) == selected_deck_class:
                cb.add_theme_stylebox_override("normal", solid_style(class_color(str(c)).darkened(0.1), 6))
                cb.add_theme_color_override("font_color", Color(0.05, 0.05, 0.05))
            else:
                cb.add_theme_stylebox_override("normal", style(class_color(str(c)).darkened(0.35), 6))
            cb.pressed.connect(switch_deck_class.bind(str(c)))
            cls_grid.add_child(cb)

    _db_sep(vb)

    # Cost filter
    var cost_lbl := Label.new(); cost_lbl.text = "COST"
    cost_lbl.add_theme_font_size_override("font_size", 11)
    cost_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.68))
    vb.add_child(cost_lbl)
    var cost_grid := GridContainer.new(); cost_grid.columns = 5
    cost_grid.add_theme_constant_override("h_separation", 3)
    cost_grid.add_theme_constant_override("v_separation", 3)
    vb.add_child(cost_grid)
    for pair in [[-1,"ALL"],[0,"0"],[1,"1"],[2,"2"],[3,"3"],[4,"4"],[5,"5"],[6,"6"],[7,"7+"]]:
        var cv: int = pair[0]; var ct: String = str(pair[1])
        var cb2 := Button.new(); cb2.text = ct
        cb2.add_theme_font_size_override("font_size", 11)
        cb2.custom_minimum_size = Vector2(28, 24)
        if _db_cost_filter == cv:
            cb2.add_theme_stylebox_override("normal", solid_style(GOLD_COLOR, 5))
            cb2.add_theme_color_override("font_color", Color(0.05, 0.05, 0.05))
        else:
            cb2.add_theme_stylebox_override("normal", style(Color(0.30, 0.24, 0.09), 5))
        cb2.pressed.connect(func(): _db_cost_filter = cv; show_deck_builder())
        cost_grid.add_child(cb2)

    _db_sep(vb)

    # Rarity filter
    var rar_lbl := Label.new(); rar_lbl.text = "RARITY"
    rar_lbl.add_theme_font_size_override("font_size", 11)
    rar_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.68))
    vb.add_child(rar_lbl)
    var rar_grid := GridContainer.new(); rar_grid.columns = 4
    rar_grid.add_theme_constant_override("h_separation", 3)
    rar_grid.add_theme_constant_override("v_separation", 3)
    vb.add_child(rar_grid)
    var rar_vals := ["","Bronze","Silver","Gold","Epic","Legendary","Platinum"]
    var rar_txts := ["ALL","BRZ","SIL","GOLD","EPIC","LEG","SIG"]
    for i in rar_vals.size():
        var rv: String = rar_vals[i]; var rt: String = rar_txts[i]
        var rb := Button.new(); rb.text = rt
        rb.add_theme_font_size_override("font_size", 10)
        rb.custom_minimum_size = Vector2(36, 24)
        if _db_rarity_filter == rv:
            rb.add_theme_stylebox_override("normal", solid_style(GOLD_COLOR, 5))
            rb.add_theme_color_override("font_color", Color(0.05, 0.05, 0.05))
        else:
            rb.add_theme_stylebox_override("normal", style(Color(0.30, 0.24, 0.09), 5))
        rb.pressed.connect(func(): _db_rarity_filter = rv; show_deck_builder())
        rar_grid.add_child(rb)

    _db_sep(vb)

    # Type filter
    var type_lbl := Label.new(); type_lbl.text = "TYPE"
    type_lbl.add_theme_font_size_override("font_size", 11)
    type_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.68))
    vb.add_child(type_lbl)
    var type_grid := GridContainer.new(); type_grid.columns = 4
    type_grid.add_theme_constant_override("h_separation", 3)
    type_grid.add_theme_constant_override("v_separation", 3)
    vb.add_child(type_grid)
    for tpair in [["","ALL"],["Follower","FOL"],["Amulet","AMU"],["Spell","SPL"]]:
        var tv: String = tpair[0]; var tt: String = tpair[1]
        var tb := Button.new(); tb.text = tt
        tb.add_theme_font_size_override("font_size", 11)
        tb.custom_minimum_size = Vector2(36, 24)
        if _db_type_filter == tv:
            tb.add_theme_stylebox_override("normal", solid_style(GOLD_COLOR, 5))
            tb.add_theme_color_override("font_color", Color(0.05, 0.05, 0.05))
        else:
            tb.add_theme_stylebox_override("normal", style(Color(0.30, 0.24, 0.09), 5))
        tb.pressed.connect(func(): _db_type_filter = tv; show_deck_builder())
        type_grid.add_child(tb)

    _db_sep(vb)

    # Owned-only toggle
    var owned_btn := Button.new()
    owned_btn.text = ("CHECK OWNED ONLY" if _db_owned_only else "CIRCLE OWNED ONLY")
    owned_btn.text = ("%s OWNED ONLY" % ("YES" if _db_owned_only else "NO"))
    owned_btn.add_theme_font_size_override("font_size", 12)
    owned_btn.custom_minimum_size = Vector2(0, 32)
    if _db_owned_only:
        owned_btn.add_theme_stylebox_override("normal", solid_style(Color(0.28, 0.65, 0.38), 8))
        owned_btn.add_theme_color_override("font_color", Color(0.04, 0.04, 0.04))
    else:
        owned_btn.add_theme_stylebox_override("normal", style(Color(0.28, 0.48, 0.28), 8))
    owned_btn.pressed.connect(func(): _db_owned_only = !_db_owned_only; show_deck_builder())
    vb.add_child(owned_btn)

    var spacer := Control.new()
    spacer.size_flags_vertical = Control.SIZE_FILL | Control.SIZE_EXPAND
    vb.add_child(spacer)

func _db_card_passes_filter(cd: Dictionary) -> bool:
    var card_class := str(cd.get("class", ""))
    var is_deck_class := (card_class == selected_deck_class)
    var is_neutral := (card_class == "Neutral" or card_class == "Universal")
    if not is_deck_class and not is_neutral: return false
    var id := str(cd.get("id", ""))
    if _db_owned_only and int(collection_owned.get(id, 0)) <= 0: return false
    if _db_cost_filter >= 0:
        var cv := int(cd.get("cost", 0))
        if _db_cost_filter == 7:
            if cv < 7: return false
        elif cv != _db_cost_filter:
            return false
    if _db_rarity_filter != "" and str(cd.get("rarity", "")) != _db_rarity_filter: return false
    if _db_type_filter != "" and str(cd.get("type", "")) != _db_type_filter: return false
    if _db_search_text.strip_edges() != "":
        var q := _db_search_text.strip_edges().to_lower()
        if not str(cd.get("name", "")).to_lower().contains(q) and not str(cd.get("effect", "")).to_lower().contains(q):
            return false
    return true

func _build_db_card_grid(parent: Control) -> void:
    var pc := PanelContainer.new()
    pc.size_flags_horizontal = Control.SIZE_FILL | Control.SIZE_EXPAND
    pc.size_flags_vertical = Control.SIZE_FILL
    var ps := StyleBoxFlat.new()
    ps.bg_color = Color(0.022, 0.028, 0.046, 1.0)
    ps.set_border_width_all(0)
    pc.add_theme_stylebox_override("panel", ps)
    parent.add_child(pc)

    var mc := MarginContainer.new()
    mc.add_theme_constant_override("margin_left", 12)
    mc.add_theme_constant_override("margin_right", 12)
    mc.add_theme_constant_override("margin_top", 10)
    mc.add_theme_constant_override("margin_bottom", 10)
    mc.size_flags_vertical = Control.SIZE_FILL
    pc.add_child(mc)

    var vb := VBoxContainer.new()
    vb.add_theme_constant_override("separation", 8)
    vb.size_flags_vertical = Control.SIZE_FILL
    mc.add_child(vb)

    var shown := 0
    for cd2 in cards:
        if _db_card_passes_filter(cd2): shown += 1
    var cnt_lbl := Label.new()
    cnt_lbl.text = "COLLECTION  -  %d cards shown" % shown
    cnt_lbl.add_theme_font_size_override("font_size", 13)
    cnt_lbl.add_theme_color_override("font_color", Color(0.52, 0.52, 0.66))
    vb.add_child(cnt_lbl)

    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_FILL | Control.SIZE_EXPAND
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    vb.add_child(scroll)

    var grid := GridContainer.new()
    grid.columns = 6
    grid.add_theme_constant_override("h_separation", 8)
    grid.add_theme_constant_override("v_separation", 8)
    scroll.add_child(grid)

    for cd in cards:
        if not _db_card_passes_filter(cd): continue
        var id := str(cd["id"])
        var rarity := str(cd["rarity"])
        var owned := int(collection_owned.get(id, 0))

        var box := VBoxContainer.new()
        box.custom_minimum_size = Vector2(112, 196)

        var cp := card_panel(cd, Vector2.ZERO, Vector2(112, 158))
        if owned <= 0:
            cp.modulate = Color(0.44, 0.48, 0.58, 0.82)
        var tap_btn := Button.new()
        tap_btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        tap_btn.flat = true
        var esb := StyleBoxEmpty.new()
        tap_btn.add_theme_stylebox_override("normal", esb)
        tap_btn.add_theme_stylebox_override("hover", esb)
        tap_btn.add_theme_stylebox_override("pressed", esb)
        var captured_cd: Dictionary = cd.duplicate()
        tap_btn.pressed.connect(func(): _show_db_card_preview(captured_cd))
        cp.add_child(tap_btn)
        box.add_child(cp)

        if owned > 0:
            var allowed := mini(owned, int(COPY_LIMITS.get(rarity, 1)))
            var in_deck := count_in_deck(id)
            var add_row := HBoxContainer.new()
            add_row.custom_minimum_size = Vector2(112, 28)
            add_row.add_theme_constant_override("separation", 2)
            var chip := Label.new()
            chip.text = "%d/%d" % [in_deck, allowed]
            chip.add_theme_font_size_override("font_size", 10)
            chip.add_theme_color_override("font_color", GOLD_COLOR if in_deck > 0 else Color(0.45, 0.45, 0.55))
            chip.custom_minimum_size = Vector2(28, 26)
            chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
            chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
            add_row.add_child(chip)
            var add_btn := Button.new(); add_btn.text = "+ ADD"
            add_btn.add_theme_font_size_override("font_size", 10)
            add_btn.size_flags_horizontal = Control.SIZE_FILL | Control.SIZE_EXPAND
            add_btn.custom_minimum_size = Vector2(0, 26)
            var can_add := (editing_deck_slot_idx >= 0 and saved_deck.size() < 40 and in_deck < allowed)
            add_btn.disabled = not can_add
            if editing_deck_slot_idx < 0:
                add_btn.tooltip_text = "Select a deck slot first"
            elif not can_add:
                add_btn.tooltip_text = "Limit reached"
            add_btn.add_theme_stylebox_override("normal", style(Color(0.22, 0.52, 0.28), 5))
            add_btn.add_theme_stylebox_override("hover", solid_style(Color(0.28, 0.62, 0.34), 5))
            add_btn.pressed.connect(add_card_to_deck.bind(id))
            add_row.add_child(add_btn)
            box.add_child(add_row)
        elif CRAFT_COSTS.has(rarity):
            var cost_v := int(CRAFT_COSTS[rarity])
            var craft_btn := Button.new()
            craft_btn.text = "CREATE %s" % _fmt_vial_cost(cost_v)
            craft_btn.add_theme_font_size_override("font_size", 9)
            craft_btn.custom_minimum_size = Vector2(112, 26)
            craft_btn.disabled = dust_balance < cost_v
            craft_btn.add_theme_stylebox_override("normal", style(Color(0.42, 0.35, 0.16), 5))
            craft_btn.pressed.connect(craft_from_deck_builder.bind(id))
            box.add_child(craft_btn)
        else:
            var locked_lbl := Label.new(); locked_lbl.text = "PACK ONLY"
            locked_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
            locked_lbl.add_theme_font_size_override("font_size", 9)
            locked_lbl.add_theme_color_override("font_color", Color(0.42, 0.42, 0.52))
            locked_lbl.custom_minimum_size = Vector2(112, 24)
            box.add_child(locked_lbl)

        grid.add_child(box)

    if grid.get_child_count() == 0:
        var empty_lbl := Label.new()
        empty_lbl.text = "No cards match the current filters."
        empty_lbl.add_theme_font_size_override("font_size", 16)
        empty_lbl.add_theme_color_override("font_color", Color(0.48, 0.48, 0.62))
        empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        grid.add_child(empty_lbl)

func _build_db_deck_panel(parent: Control) -> void:
    var pc := PanelContainer.new()
    pc.custom_minimum_size = Vector2(314, 0)
    pc.size_flags_vertical = Control.SIZE_FILL
    var ps := StyleBoxFlat.new()
    ps.bg_color = Color(0.020, 0.025, 0.042, 1.0)
    ps.border_color = Color(0.12, 0.10, 0.05)
    ps.set_border_width_all(0); ps.border_width_left = 1
    pc.add_theme_stylebox_override("panel", ps)
    parent.add_child(pc)

    var mc := MarginContainer.new()
    mc.add_theme_constant_override("margin_left", 10)
    mc.add_theme_constant_override("margin_right", 10)
    mc.add_theme_constant_override("margin_top", 10)
    mc.add_theme_constant_override("margin_bottom", 10)
    mc.size_flags_vertical = Control.SIZE_FILL
    pc.add_child(mc)

    var vb := VBoxContainer.new()
    vb.add_theme_constant_override("separation", 8)
    vb.size_flags_vertical = Control.SIZE_FILL
    mc.add_child(vb)

    _build_db_slot_strip(vb)
    _db_sep(vb)

    if editing_deck_slot_idx < 0:
        var hint := Label.new()
        hint.text = "Select a slot above to start building."
        hint.add_theme_font_size_override("font_size", 14)
        hint.add_theme_color_override("font_color", Color(0.48, 0.48, 0.64))
        hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        vb.add_child(hint)
        return

    var slot: Dictionary = deck_slots[editing_deck_slot_idx]
    var slot_class := str(slot.get("class", "Hope"))

    var leader_row := HBoxContainer.new()
    leader_row.custom_minimum_size = Vector2(0, 88)
    leader_row.add_theme_constant_override("separation", 10)
    vb.add_child(leader_row)

    var lf := Panel.new()
    lf.custom_minimum_size = Vector2(70, 86); lf.clip_contents = true
    lf.add_theme_stylebox_override("panel", style(class_color(slot_class).darkened(0.25), 8))
    leader_row.add_child(lf)
    var la := TextureRect.new()
    la.texture = class_leader_texture(slot_class)
    la.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    la.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    la.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    la.clip_contents = true; la.mouse_filter = Control.MOUSE_FILTER_IGNORE
    lf.add_child(la)

    var info_vb := VBoxContainer.new()
    info_vb.size_flags_horizontal = Control.SIZE_FILL | Control.SIZE_EXPAND
    info_vb.add_theme_constant_override("separation", 3)
    leader_row.add_child(info_vb)

    var dname_lbl := Label.new()
    dname_lbl.text = str(slot.get("name", "Deck %d" % (editing_deck_slot_idx + 1)))
    dname_lbl.add_theme_font_size_override("font_size", 15)
    dname_lbl.add_theme_color_override("font_color", GOLD_COLOR)
    dname_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    info_vb.add_child(dname_lbl)

    var dclass_lbl := Label.new()
    dclass_lbl.text = slot_class.to_upper()
    dclass_lbl.add_theme_font_size_override("font_size", 12)
    dclass_lbl.add_theme_color_override("font_color", class_color(slot_class).lightened(0.22))
    info_vb.add_child(dclass_lbl)

    var is_valid := deck_validation_text().begins_with("DECK VALID")
    var valid_lbl := Label.new()
    valid_lbl.text = "%d / 40  -  %s" % [saved_deck.size(), "VALID" if is_valid else "INVALID"]
    valid_lbl.add_theme_font_size_override("font_size", 12)
    valid_lbl.add_theme_color_override("font_color", GOLD_COLOR if is_valid else Color(1.0, 0.45, 0.40))
    info_vb.add_child(valid_lbl)

    var rename_btn := Button.new(); rename_btn.text = "RENAME"
    rename_btn.add_theme_font_size_override("font_size", 11)
    rename_btn.custom_minimum_size = Vector2(0, 24)
    rename_btn.add_theme_stylebox_override("normal", style(Color(0.38, 0.32, 0.14), 5))
    rename_btn.pressed.connect(func(): _show_db_rename_overlay())
    info_vb.add_child(rename_btn)

    _build_db_cost_curve(vb, saved_deck)
    _db_sep(vb)

    var dl_hdr := Label.new(); dl_hdr.text = "DECK LIST  (cost, then name)"
    dl_hdr.add_theme_font_size_override("font_size", 11)
    dl_hdr.add_theme_color_override("font_color", Color(0.52, 0.52, 0.66))
    vb.add_child(dl_hdr)

    var list_scroll := ScrollContainer.new()
    list_scroll.size_flags_vertical = Control.SIZE_FILL | Control.SIZE_EXPAND
    list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    vb.add_child(list_scroll)

    var list_vb := VBoxContainer.new()
    list_vb.add_theme_constant_override("separation", 3)
    list_vb.size_flags_horizontal = Control.SIZE_FILL
    list_scroll.add_child(list_vb)
    _build_db_deck_list_entries(list_vb)

    _db_sep(vb)

    var act_vb := VBoxContainer.new()
    act_vb.add_theme_constant_override("separation", 5)
    vb.add_child(act_vb)
    var row1 := HBoxContainer.new()
    row1.add_theme_constant_override("separation", 5)
    act_vb.add_child(row1)
    var dup_btn := Button.new(); dup_btn.text = "DUPLICATE"
    dup_btn.size_flags_horizontal = Control.SIZE_FILL | Control.SIZE_EXPAND
    dup_btn.add_theme_font_size_override("font_size", 12)
    dup_btn.add_theme_stylebox_override("normal", style(Color(0.28, 0.50, 0.40), 7))
    dup_btn.pressed.connect(func():
        _duplicate_deck_slot(editing_deck_slot_idx)
        editing_deck_slot_idx = -1
        show_deck_manager())
    row1.add_child(dup_btn)
    var del_btn := Button.new(); del_btn.text = "DELETE"
    del_btn.size_flags_horizontal = Control.SIZE_FILL | Control.SIZE_EXPAND
    del_btn.add_theme_font_size_override("font_size", 12)
    del_btn.add_theme_stylebox_override("normal", style(Color(0.62, 0.16, 0.16), 7))
    del_btn.pressed.connect(func(): _confirm_delete_slot(editing_deck_slot_idx))
    row1.add_child(del_btn)
    var reset_btn := Button.new(); reset_btn.text = "RESET TO STARTER"
    reset_btn.add_theme_font_size_override("font_size", 12)
    reset_btn.custom_minimum_size = Vector2(0, 32)
    reset_btn.add_theme_stylebox_override("normal", style(Color(0.42, 0.34, 0.14), 7))
    reset_btn.pressed.connect(func(): build_starter_deck(selected_deck_class); save_profile(); show_deck_builder())
    act_vb.add_child(reset_btn)
    var auto_build_btn := Button.new(); auto_build_btn.text = "✦ AUTO-BUILD DECK"
    auto_build_btn.add_theme_font_size_override("font_size", 12)
    auto_build_btn.custom_minimum_size = Vector2(0, 34)
    auto_build_btn.add_theme_stylebox_override("normal", style(Color(0.20, 0.36, 0.58), 7))
    auto_build_btn.add_theme_stylebox_override("hover", style(Color(0.28, 0.46, 0.72), 7))
    auto_build_btn.pressed.connect(func(): show_auto_build_class_select(false))
    act_vb.add_child(auto_build_btn)

func _build_db_slot_strip(parent: Control) -> void:
    var hdr := Label.new()
    hdr.text = "CUSTOM DECKS  (%d / %d)" % [deck_slots.size(), MAX_DECK_SLOTS]
    hdr.add_theme_font_size_override("font_size", 12)
    hdr.add_theme_color_override("font_color", GOLD_COLOR)
    parent.add_child(hdr)

    var grid := GridContainer.new(); grid.columns = 4
    grid.add_theme_constant_override("h_separation", 4)
    grid.add_theme_constant_override("v_separation", 4)
    parent.add_child(grid)

    for i in range(MAX_DECK_SLOTS):
        var slot_btn := Button.new()
        slot_btn.custom_minimum_size = Vector2(68, 46)
        slot_btn.add_theme_font_size_override("font_size", 10)
        var is_active := (i == editing_deck_slot_idx)
        if i < deck_slots.size():
            var sl: Dictionary = deck_slots[i]
            var sl_cls := str(sl.get("class", "Hope"))
            var sl_name := str(sl.get("name", "Deck %d" % (i + 1)))
            var card_count := int(Array(sl.get("cards", [])).size())
            slot_btn.text = "%d. %s\n%d/40" % [i + 1, sl_name.left(7), card_count]
            slot_btn.tooltip_text = sl_name
            if is_active:
                slot_btn.add_theme_stylebox_override("normal", solid_style(class_color(sl_cls), 6))
                slot_btn.add_theme_color_override("font_color", Color(0.04, 0.04, 0.04))
            else:
                slot_btn.add_theme_stylebox_override("normal", style(class_color(sl_cls).darkened(0.52), 6))
            var ci := i
            slot_btn.pressed.connect(func(): _open_slot_in_deck_builder(ci))
        else:
            slot_btn.text = "%d.\nNEW" % (i + 1)
            slot_btn.tooltip_text = "Create new deck in slot %d" % (i + 1)
            slot_btn.add_theme_stylebox_override("normal", style(Color(0.16, 0.20, 0.34), 6))
            slot_btn.add_theme_color_override("font_color", Color(0.44, 0.54, 0.82))
            slot_btn.pressed.connect(func(): _show_create_slot_overlay())
        grid.add_child(slot_btn)

func _build_db_cost_curve(parent: Control, deck: Array) -> void:
    if deck.is_empty(): return
    var cl := Label.new(); cl.text = "MANA CURVE"
    cl.add_theme_font_size_override("font_size", 11)
    cl.add_theme_color_override("font_color", Color(0.52, 0.52, 0.66))
    parent.add_child(cl)

    var buckets := [0, 0, 0, 0, 0, 0, 0, 0]
    for id in deck:
        var cdd := card_by_id(str(id))
        if cdd.is_empty(): continue
        buckets[mini(int(cdd.get("cost", 0)), 7)] += 1
    var max_b := 1
    for b in buckets:
        if b > max_b: max_b = b

    var hbox := HBoxContainer.new()
    hbox.custom_minimum_size = Vector2(0, 52)
    hbox.add_theme_constant_override("separation", 3)
    parent.add_child(hbox)
    for i in range(8):
        var col := VBoxContainer.new()
        col.size_flags_horizontal = Control.SIZE_FILL | Control.SIZE_EXPAND
        col.add_theme_constant_override("separation", 2)
        hbox.add_child(col)
        var bar_h := 28
        var bar_bg := Panel.new(); bar_bg.custom_minimum_size = Vector2(0, bar_h)
        bar_bg.size_flags_horizontal = Control.SIZE_FILL
        var bg_s := StyleBoxFlat.new(); bg_s.bg_color = Color(0.08, 0.10, 0.18)
        bg_s.set_corner_radius_all(4)
        bar_bg.add_theme_stylebox_override("panel", bg_s); col.add_child(bar_bg)
        if buckets[i] > 0:
            var fill_h := int(float(buckets[i]) / float(max_b) * bar_h)
            var fill := Panel.new()
            fill.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
            fill.offset_top = bar_h - fill_h; fill.offset_bottom = 0
            var fs := StyleBoxFlat.new()
            fs.bg_color = Color(0.35, 0.50, 0.92, 0.88).lerp(GOLD_COLOR, float(i) / 7.0)
            fs.set_corner_radius_all(3)
            fill.add_theme_stylebox_override("panel", fs); bar_bg.add_child(fill)
        var cnt_l := Label.new()
        cnt_l.text = str(buckets[i]) if buckets[i] > 0 else ""
        cnt_l.add_theme_font_size_override("font_size", 10)
        cnt_l.add_theme_color_override("font_color", Color(0.68, 0.68, 0.82))
        cnt_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; col.add_child(cnt_l)
        var lbl_c := Label.new()
        lbl_c.text = str(i) if i < 7 else "7+"
        lbl_c.add_theme_font_size_override("font_size", 10)
        lbl_c.add_theme_color_override("font_color", Color(0.44, 0.44, 0.54))
        lbl_c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; col.add_child(lbl_c)

func _build_db_deck_list_entries(parent: Control) -> void:
    if saved_deck.is_empty():
        var el := Label.new(); el.text = "No cards added yet."
        el.add_theme_font_size_override("font_size", 13)
        el.add_theme_color_override("font_color", Color(0.40, 0.40, 0.52))
        parent.add_child(el)
        return
    var counts: Dictionary = {}
    for id in saved_deck:
        counts[str(id)] = int(counts.get(str(id), 0)) + 1
    var order: Array = counts.keys()
    order.sort_custom(func(a: String, b: String) -> bool:
        var ca := card_by_id(a); var cbb := card_by_id(b)
        var ca_cost := int(ca.get("cost", 0)) if not ca.is_empty() else 99
        var cb_cost := int(cbb.get("cost", 0)) if not cbb.is_empty() else 99
        if ca_cost != cb_cost: return ca_cost < cb_cost
        var na := str(ca.get("name", a)) if not ca.is_empty() else a
        var nb := str(cbb.get("name", b)) if not cbb.is_empty() else b
        return na < nb)
    for id in order:
        var cd := card_by_id(id)
        if cd.is_empty(): continue
        var row := HBoxContainer.new()
        row.custom_minimum_size = Vector2(0, 30)
        row.add_theme_constant_override("separation", 4)
        var cost_p := Panel.new(); cost_p.custom_minimum_size = Vector2(24, 28)
        var cs := StyleBoxFlat.new(); cs.bg_color = Color(0.10, 0.16, 0.30)
        cs.set_corner_radius_all(5)
        cost_p.add_theme_stylebox_override("panel", cs)
        var cost_l := Label.new(); cost_l.text = str(card_int_value(cd, "cost"))
        cost_l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        cost_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        cost_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        cost_l.add_theme_font_size_override("font_size", 12)
        cost_l.add_theme_color_override("font_color", Color(0.70, 0.85, 1.0))
        cost_p.add_child(cost_l); row.add_child(cost_p)
        var cx := Label.new(); cx.text = "x%d" % int(counts[id])
        cx.custom_minimum_size = Vector2(22, 28)
        cx.add_theme_font_size_override("font_size", 12)
        cx.add_theme_color_override("font_color", GOLD_COLOR)
        cx.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; row.add_child(cx)
        var sw := ColorRect.new()
        sw.color = class_color(str(cd.get("class", "Neutral")))
        sw.custom_minimum_size = Vector2(4, 28); row.add_child(sw)
        var nl := Label.new(); nl.text = str(cd.get("name", id))
        nl.size_flags_horizontal = Control.SIZE_FILL | Control.SIZE_EXPAND
        nl.custom_minimum_size = Vector2(0, 28)
        nl.add_theme_font_size_override("font_size", 12)
        nl.clip_text = true; nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        row.add_child(nl)
        var rb := Button.new(); rb.text = "-"
        rb.custom_minimum_size = Vector2(26, 28)
        rb.add_theme_font_size_override("font_size", 14)
        rb.add_theme_stylebox_override("normal", style(Color(0.55, 0.18, 0.18), 5))
        rb.tooltip_text = "Remove one copy"
        rb.pressed.connect(remove_one_from_deck.bind(id))
        row.add_child(rb)
        parent.add_child(row)

func _show_db_card_preview(card_data: Dictionary) -> void:
    var id := str(card_data.get("id", ""))
    var rarity := str(card_data.get("rarity", "Bronze"))
    var owned := int(collection_owned.get(id, 0))
    var in_deck := count_in_deck(id)
    var allowed := mini(owned, int(COPY_LIMITS.get(rarity, 1)))

    var overlay := Panel.new()
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.z_index = 800
    var ov_s := StyleBoxFlat.new(); ov_s.bg_color = Color(0.0, 0.0, 0.0, 0.70)
    ov_s.set_border_width_all(0)
    overlay.add_theme_stylebox_override("panel", ov_s)
    root_layer.add_child(overlay)

    var esb := StyleBoxEmpty.new()
    var close_bg := Button.new()
    close_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    close_bg.flat = true
    close_bg.add_theme_stylebox_override("normal", esb)
    close_bg.add_theme_stylebox_override("hover", esb)
    close_bg.pressed.connect(func(): overlay.queue_free())
    overlay.add_child(close_bg)

    var pv := Panel.new()
    pv.position = Vector2(285, 72); pv.size = Vector2(710, 576)
    pv.z_index = 1
    var pv_s := StyleBoxFlat.new()
    pv_s.bg_color = Color(0.032, 0.040, 0.065, 0.97)
    pv_s.border_color = GOLD_COLOR; pv_s.set_border_width_all(2)
    pv_s.set_corner_radius_all(16)
    pv_s.shadow_color = Color(0, 0, 0, 0.70); pv_s.shadow_size = 22
    pv.add_theme_stylebox_override("panel", pv_s)
    overlay.add_child(pv)

    var eat := Button.new(); eat.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    eat.flat = true; eat.add_theme_stylebox_override("normal", esb)
    eat.add_theme_stylebox_override("hover", esb)
    pv.add_child(eat)

    var cp2 := card_panel(card_data, Vector2(22, 22), Vector2(272, 370))
    pv.add_child(cp2)

    var ix := 312.0
    var nl2 := label(str(card_data.get("name", "")), Vector2(ix, 22), Vector2(374, 36), 22, pv)
    nl2.add_theme_color_override("font_color", GOLD_COLOR)
    var cl2 := label("%s  -  %s  -  Cost %s" % [str(card_data.get("class","")), rarity, str(card_data.get("cost","?"))], Vector2(ix, 62), Vector2(374, 22), 13, pv)
    cl2.add_theme_color_override("font_color", class_color(str(card_data.get("class","Neutral"))).lightened(0.18))
    label("Type: %s" % str(card_data.get("type","Follower")), Vector2(ix, 88), Vector2(374, 22), 13, pv).add_theme_color_override("font_color", Color(0.60, 0.60, 0.72))

    var stat_y := 116.0
    if card_data.has("attack") and card_data.has("health"):
        var sl2 := label("ATK %s  /  HP %s" % [str(card_data.get("attack","?")), str(card_data.get("health","?"))], Vector2(ix, stat_y), Vector2(240, 26), 16, pv)
        sl2.add_theme_color_override("font_color", Color(0.88, 0.84, 0.62))
        stat_y += 34.0

    var eff := label(str(card_data.get("effect","No effect.")), Vector2(ix, stat_y), Vector2(376, 200), 14, pv)
    eff.add_theme_color_override("font_color", Color(0.86, 0.86, 0.92))
    eff.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

    label("Owned: %d  -  In deck: %d / %d" % [owned, in_deck, allowed], Vector2(ix, 328), Vector2(376, 22), 13, pv).add_theme_color_override("font_color", Color(0.60, 0.75, 0.60))

    button("CLOSE", Vector2(ix, 368), Vector2(120, 38), func(): overlay.queue_free(), pv)
    if editing_deck_slot_idx >= 0 and owned > 0:
        var add_pv := button("+ ADD TO DECK", Vector2(ix + 130, 368), Vector2(210, 38),
            func(): add_card_to_deck(id); overlay.queue_free(), pv)
        if saved_deck.size() >= 40 or in_deck >= allowed:
            add_pv.disabled = true
        if in_deck > 0:
            button("- REMOVE", Vector2(ix, 416), Vector2(160, 36),
                func(): remove_one_from_deck(id); overlay.queue_free(), pv)

func _show_create_slot_overlay() -> void:
    if deck_slots.size() >= MAX_DECK_SLOTS: return

    var overlay := Panel.new()
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.z_index = 900
    var ov_s := StyleBoxFlat.new(); ov_s.bg_color = Color(0, 0, 0, 0.70)
    ov_s.set_border_width_all(0)
    overlay.add_theme_stylebox_override("panel", ov_s)
    root_layer.add_child(overlay)

    var esb := StyleBoxEmpty.new()
    var bg_btn := Button.new(); bg_btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg_btn.flat = true; bg_btn.add_theme_stylebox_override("normal", esb)
    bg_btn.add_theme_stylebox_override("hover", esb)
    bg_btn.pressed.connect(func(): overlay.queue_free())
    overlay.add_child(bg_btn)

    var box := Panel.new()
    box.position = Vector2(388, 162); box.size = Vector2(504, 396)
    box.z_index = 1; box.add_theme_stylebox_override("panel", style(GOLD_COLOR, 16))
    overlay.add_child(box)

    var eat := Button.new(); eat.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    eat.flat = true; eat.add_theme_stylebox_override("normal", esb)
    eat.add_theme_stylebox_override("hover", esb)
    box.add_child(eat)

    label("CREATE NEW DECK", Vector2(22, 20), Vector2(460, 36), 22, box).add_theme_color_override("font_color", GOLD_COLOR)
    label("Choose a class and give your deck a name.", Vector2(22, 58), Vector2(460, 22), 13, box).add_theme_color_override("font_color", Color(0.62, 0.62, 0.72))
    label("CLASS", Vector2(22, 90), Vector2(100, 22), 12, box).add_theme_color_override("font_color", Color(0.55, 0.55, 0.68))

    var chosen := [selected_class if selected_class != "" else "Hope"]
    var cls_hbox := HBoxContainer.new()
    cls_hbox.position = Vector2(22, 112); cls_hbox.size = Vector2(460, 50)
    cls_hbox.add_theme_constant_override("separation", 8)
    box.add_child(cls_hbox)

    var cbs: Array = []
    for c in CLASSES:
        var cb3 := Button.new(); cb3.text = str(c)
        cb3.custom_minimum_size = Vector2(105, 46)
        cb3.add_theme_font_size_override("font_size", 14)
        cbs.append(cb3); cls_hbox.add_child(cb3)

    var refresh_cls: Callable
    refresh_cls = func():
        for i in cbs.size():
            var c2: String = CLASSES[i]
            if c2 == chosen[0]:
                cbs[i].add_theme_stylebox_override("normal", solid_style(class_color(c2).darkened(0.08), 8))
                cbs[i].add_theme_color_override("font_color", Color(0.04, 0.04, 0.04))
            else:
                cbs[i].add_theme_stylebox_override("normal", style(class_color(c2).darkened(0.40), 8))
                cbs[i].remove_theme_color_override("font_color")
    refresh_cls.call()
    for i in cbs.size():
        var c3: String = CLASSES[i]
        cbs[i].pressed.connect(func(): chosen[0] = c3; refresh_cls.call())

    label("DECK NAME", Vector2(22, 174), Vector2(200, 22), 12, box).add_theme_color_override("font_color", Color(0.55, 0.55, 0.68))
    var name_edit := LineEdit.new()
    name_edit.position = Vector2(22, 196); name_edit.size = Vector2(460, 42)
    name_edit.placeholder_text = "My Deck"
    name_edit.add_theme_font_size_override("font_size", 16)
    box.add_child(name_edit)

    button("CANCEL", Vector2(22, 298), Vector2(200, 50), func(): overlay.queue_free(), box)
    button("CREATE DECK", Vector2(240, 298), Vector2(240, 50),
        func():
            var dname := name_edit.text.strip_edges()
            if dname.is_empty(): dname = "My %s Deck" % chosen[0]
            deck_slots.append({"name": dname, "class": chosen[0], "cards": []})
            save_profile()
            overlay.queue_free()
            _open_slot_in_deck_builder(deck_slots.size() - 1),
        box)

func _show_db_rename_overlay() -> void:
    if editing_deck_slot_idx < 0 or editing_deck_slot_idx >= deck_slots.size(): return
    var cur_name := str(deck_slots[editing_deck_slot_idx].get("name", "Deck %d" % (editing_deck_slot_idx + 1)))

    var overlay := Panel.new()
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.z_index = 900
    var ov_s := StyleBoxFlat.new(); ov_s.bg_color = Color(0, 0, 0, 0.65)
    ov_s.set_border_width_all(0)
    overlay.add_theme_stylebox_override("panel", ov_s)
    root_layer.add_child(overlay)

    var esb := StyleBoxEmpty.new()
    var bg_btn := Button.new(); bg_btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg_btn.flat = true; bg_btn.add_theme_stylebox_override("normal", esb)
    bg_btn.add_theme_stylebox_override("hover", esb)
    bg_btn.pressed.connect(func(): overlay.queue_free())
    overlay.add_child(bg_btn)

    var box := Panel.new()
    box.position = Vector2(388, 242); box.size = Vector2(504, 236)
    box.z_index = 1; box.add_theme_stylebox_override("panel", style(GOLD_COLOR, 16))
    overlay.add_child(box)

    var eat := Button.new(); eat.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    eat.flat = true; eat.add_theme_stylebox_override("normal", esb)
    eat.add_theme_stylebox_override("hover", esb)
    box.add_child(eat)

    label("RENAME DECK", Vector2(22, 20), Vector2(460, 34), 20, box).add_theme_color_override("font_color", GOLD_COLOR)
    var name_edit := LineEdit.new()
    name_edit.position = Vector2(22, 68); name_edit.size = Vector2(460, 44)
    name_edit.text = cur_name
    name_edit.add_theme_font_size_override("font_size", 16)
    box.add_child(name_edit)
    name_edit.select_all()

    button("CANCEL", Vector2(22, 132), Vector2(200, 50), func(): overlay.queue_free(), box)
    button("SAVE NAME", Vector2(240, 132), Vector2(240, 50),
        func():
            var new_name := name_edit.text.strip_edges()
            if not new_name.is_empty():
                deck_slots[editing_deck_slot_idx]["name"] = new_name
                save_profile()
                overlay.queue_free()
                show_deck_builder(),
        box)

func add_card_to_deck(id: String) -> void:
    var cd := card_by_id(id)
    if cd.is_empty():
        return
    var owned := int(collection_owned.get(id, 0))
    var limit := mini(owned, int(COPY_LIMITS.get(str(cd.get("rarity", "Bronze")), 1)))
    if saved_deck.size() >= 40 or count_in_deck(id) >= limit:
        return
    saved_deck.append(id)
    save_profile()
    show_deck_builder()

func remove_one_from_deck(id: String) -> void:
    var index := saved_deck.find(id)
    if index >= 0:
        saved_deck.remove_at(index)
        save_profile()
        show_deck_builder()

func craft_from_deck_builder(id: String) -> void:
    var cd := card_by_id(id)
    if cd.is_empty():
        return
    var rarity := str(cd.get("rarity", "Bronze"))
    if not CRAFT_COSTS.has(rarity):
        return
    var cost := int(CRAFT_COSTS[rarity])
    var owned := int(collection_owned.get(id, 0))
    var limit := int(COPY_LIMITS.get(rarity, 1))
    if owned >= limit or dust_balance < cost:
        return
    dust_balance -= cost
    collection_owned[id] = owned + 1
    save_profile()
    show_deck_builder()

## ── Multi-deck slot helpers ──────────────────────────────────────────────────

func _migrate_saved_decks_to_slots() -> void:
    # Migrate the old one-deck-per-class format into numbered slots (slot 0 first).
    for cls in CLASSES:
        var ids: Array = Array(saved_decks.get(str(cls), []))
        if ids.is_empty():
            continue
        if deck_slots.size() >= MAX_DECK_SLOTS:
            break
        deck_slots.append({"name": "My %s Deck" % str(cls), "class": str(cls), "cards": ids.duplicate()})
    print("DECK MIGRATION: migrated %d class deck(s) into numbered slots" % deck_slots.size())

func _slot_validation_text(slot: Dictionary) -> String:
    var cls := str(slot.get("class", ""))
    var cards: Array = Array(slot.get("cards", []))
    if cards.size() != 40:
        return "Deck has %d/40 cards." % cards.size()
    var counts: Dictionary = {}
    for id in cards:
        counts[str(id)] = int(counts.get(str(id), 0)) + 1
    for id in counts.keys():
        var cd := card_by_id(id)
        if cd.is_empty():
            return "Unknown card: %s" % id
        var card_class := str(cd.get("class", ""))
        if card_class != cls and card_class != "Neutral" and card_class != "Universal":
            return "This card does not belong to %s: %s." % [cls, str(cd.get("name", id))]
        var rarity := str(cd.get("rarity", "Bronze"))
        var limit := int(COPY_LIMITS.get(rarity, 1))
        if int(counts[id]) > limit:
            return "Too many copies of %s (max %d)." % [str(cd.get("name", id)), limit]
    return "DECK VALID — 40 CARDS"

func _slot_is_valid(slot: Dictionary) -> bool:
    return _slot_validation_text(slot).begins_with("DECK VALID")

func _create_new_deck_slot() -> void:
    if deck_slots.size() >= MAX_DECK_SLOTS:
        return
    var new_class := selected_class if selected_class != "" else "Hope"
    deck_slots.append({"name": "New Deck %d" % (deck_slots.size() + 1), "class": new_class, "cards": []})
    save_profile()
    _open_slot_in_deck_builder(deck_slots.size() - 1)

func _open_slot_in_deck_builder(slot_idx: int) -> void:
    if slot_idx < 0 or slot_idx >= deck_slots.size():
        return
    editing_deck_slot_idx = slot_idx
    var slot: Dictionary = deck_slots[slot_idx]
    selected_deck_class = str(slot.get("class", selected_class if selected_class != "" else "Hope"))
    saved_deck = Array(slot.get("cards", []))
    show_deck_builder()

func _duplicate_deck_slot(slot_idx: int) -> void:
    if slot_idx < 0 or slot_idx >= deck_slots.size() or deck_slots.size() >= MAX_DECK_SLOTS:
        return
    var src: Dictionary = deck_slots[slot_idx].duplicate(true)
    src["name"] = str(src.get("name", "Deck")) + " (Copy)"
    deck_slots.append(src)
    save_profile()
    show_deck_manager()

func _confirm_delete_slot(slot_idx: int) -> void:
    if slot_idx < 0 or slot_idx >= deck_slots.size():
        return
    var slot_name := str(deck_slots[slot_idx].get("name", "Deck %d" % (slot_idx + 1)))
    # Show a small confirmation overlay instead of wiping immediately.
    var overlay := Panel.new()
    overlay.position = Vector2(340, 220)
    overlay.size = Vector2(600, 240)
    overlay.add_theme_stylebox_override("panel", style(Color(0.18, 0.06, 0.06), 14))
    overlay.z_index = 500
    root_layer.add_child(overlay)
    centered_label("Delete \"%s\"?" % slot_name, Vector2(30, 28), Vector2(540, 40), 22, overlay).add_theme_color_override("font_color", Color(1.0, 0.55, 0.5))
    centered_label("This cannot be undone.", Vector2(80, 78), Vector2(440, 28), 15, overlay)
    button("CANCEL", Vector2(100, 155), Vector2(180, 48), func(): overlay.queue_free(), overlay)
    button("DELETE", Vector2(320, 155), Vector2(180, 48),
        func():
            deck_slots.remove_at(slot_idx)
            if last_trial_deck_idx == slot_idx: last_trial_deck_idx = -1
            elif last_trial_deck_idx > slot_idx: last_trial_deck_idx -= 1
            if last_battle_deck_idx == slot_idx: last_battle_deck_idx = -1
            elif last_battle_deck_idx > slot_idx: last_battle_deck_idx -= 1
            overlay.queue_free()
            save_profile()
            show_deck_manager(),
        overlay)

func show_deck_manager() -> void:
    editing_deck_slot_idx = -1
    clear_screen(); add_background(0.72)
    header("MY DECKS", "Up to %d saved decks • tap a slot to build, duplicate, or delete" % MAX_DECK_SLOTS)
    button("BACK", Vector2(28, 662), Vector2(160, 42), show_home)

    for i in range(MAX_DECK_SLOTS):
        var col: int = i % 4
        var row: int = i / 4
        var px: float = 28.0 + col * 311.0
        var py: float = 163.0 + row * 190.0
        var sp := Panel.new()
        sp.position = Vector2(px, py)
        sp.size = Vector2(295, 172)

        if i < deck_slots.size():
            var slot: Dictionary = deck_slots[i]
            var slot_class := str(slot.get("class", "Hope"))
            sp.add_theme_stylebox_override("panel", style(class_color(slot_class).darkened(0.45), 12))
            root_layer.add_child(sp)

            label(str(slot.get("name", "Deck %d" % (i + 1))), Vector2(8, 7), Vector2(174, 26), 14, sp).add_theme_color_override("font_color", GOLD_COLOR)
            label(slot_class.to_upper(), Vector2(8, 35), Vector2(130, 20), 11, sp).add_theme_color_override("font_color", class_color(slot_class).lightened(0.3))

            var card_count: int = int(Array(slot.get("cards", [])).size())
            var valid: bool = _slot_is_valid(slot)
            var status_txt := "%d/40  •  %s" % [card_count, "VALID ✓" if valid else "INVALID"]
            label(status_txt, Vector2(8, 55), Vector2(278, 20), 11, sp).add_theme_color_override("font_color", GOLD_COLOR if valid else Color(1.0, 0.55, 0.5))

            # "in use" badges
            if last_battle_deck_idx == i:
                label("⚔ BATTLE DECK", Vector2(148, 7), Vector2(136, 18), 10, sp).add_theme_color_override("font_color", Color(0.55, 0.9, 1.0))
            if last_trial_deck_idx == i:
                label("⚡ TRIAL DECK", Vector2(148, 26), Vector2(136, 18), 10, sp).add_theme_color_override("font_color", Color(1.0, 0.82, 0.35))

            var captured_i := i
            button("EDIT", Vector2(8, 80), Vector2(80, 34), func(): _open_slot_in_deck_builder(captured_i), sp)
            button("DUP",  Vector2(98, 80), Vector2(80, 34), func(): _duplicate_deck_slot(captured_i), sp)
            button("DEL",  Vector2(188, 80), Vector2(80, 34), func(): _confirm_delete_slot(captured_i), sp)
            button("⚔ BATTLES", Vector2(8, 122), Vector2(132, 38),
                func():
                    last_battle_deck_idx = captured_i
                    save_profile()
                    show_deck_manager(),
                sp)
            button("⚡ TRIALS", Vector2(150, 122), Vector2(132, 38),
                func():
                    last_trial_deck_idx = captured_i
                    save_profile()
                    show_deck_manager(),
                sp)
        else:
            sp.add_theme_stylebox_override("panel", style(Color(0.07, 0.09, 0.14), 12))
            root_layer.add_child(sp)
            label("SLOT %d" % (i + 1), Vector2(10, 12), Vector2(274, 22), 12, sp).add_theme_color_override("font_color", Color(0.32, 0.32, 0.45))
            button("+ CREATE NEW DECK", Vector2(42, 64), Vector2(210, 46), func(): _create_new_deck_slot(), sp)

func show_trial_deck_picker(opponent_class: String, tier: int) -> void:
    clear_screen(); add_background(0.72)
    var tier_names := ["Rookie", "Challenger", "Elite", "SPONSOR BOSS"]
    var tier_label: String = tier_names[clampi(tier - 1, 0, tier_names.size() - 1)]
    header("CHOOSE YOUR DECK", "Trial vs %s — Tier %d: %s" % [opponent_class, tier, tier_label])

    # ── Left panel: scrollable slot list ─────────────────────────────────────
    var list_panel := Panel.new()
    list_panel.position = Vector2(28, 162)
    list_panel.size = Vector2(720, 490)
    list_panel.add_theme_stylebox_override("panel", style(Color(0.04, 0.06, 0.10), 12))
    root_layer.add_child(list_panel)

    var scroll := ScrollContainer.new()
    scroll.position = Vector2(8, 8)
    scroll.size = Vector2(704, 474)
    list_panel.add_child(scroll)
    var vbox := VBoxContainer.new()
    vbox.custom_minimum_size = Vector2(690, 0)
    vbox.add_theme_constant_override("separation", 10)
    scroll.add_child(vbox)

    # Prebuilt starter deck option (always available)
    var prebuilt_row := _build_trial_deck_row("STARTER DECK (%s)" % (selected_class if selected_class != "" else "Hope"),
        selected_class if selected_class != "" else "Hope", 40, true, last_trial_deck_idx == -1)
    prebuilt_row.pressed.connect(func():
        last_trial_deck_idx = -1
        save_profile()
        show_trial_deck_picker(opponent_class, tier))
    vbox.add_child(prebuilt_row)

    for i in range(deck_slots.size()):
        var slot: Dictionary = deck_slots[i]
        var valid: bool = _slot_is_valid(slot)
        var card_count: int = int(Array(slot.get("cards", [])).size())
        var deck_name := str(slot.get("name", "Deck %d" % (i + 1)))
        var slot_class := str(slot.get("class", "Hope"))
        var row := _build_trial_deck_row(deck_name, slot_class, card_count, valid, last_trial_deck_idx == i)
        var captured_i := i
        row.pressed.connect(func():
            last_trial_deck_idx = captured_i
            save_profile()
            show_trial_deck_picker(opponent_class, tier))
        vbox.add_child(row)

    if deck_slots.is_empty():
        centered_label("No custom decks yet — go to MY DECKS to create one.", Vector2(60, 200), Vector2(590, 60), 16, list_panel)

    # ── Right panel: selection info + start button ────────────────────────────
    var info := Panel.new()
    info.position = Vector2(765, 162)
    info.size = Vector2(487, 490)
    info.add_theme_stylebox_override("panel", style(Color(0.07, 0.10, 0.18), 14))
    root_layer.add_child(info)

    var chosen_name := "STARTER DECK"
    var chosen_valid := true
    var chosen_class := selected_class if selected_class != "" else "Hope"
    if last_trial_deck_idx >= 0 and last_trial_deck_idx < deck_slots.size():
        var cs: Dictionary = deck_slots[last_trial_deck_idx]
        chosen_name = str(cs.get("name", "Deck"))
        chosen_class = str(cs.get("class", "Hope"))
        chosen_valid = _slot_is_valid(cs)

    # Leader art
    var art := TextureRect.new()
    art.texture = class_leader_texture(chosen_class)
    art.position = Vector2(130, 16)
    art.size = Vector2(228, 170)
    art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    art.clip_contents = true
    info.add_child(art)

    label(chosen_name, Vector2(16, 194), Vector2(455, 34), 20, info).add_theme_color_override("font_color", GOLD_COLOR)
    label(chosen_class.to_upper(), Vector2(16, 232), Vector2(200, 26), 15, info).add_theme_color_override("font_color", class_color(chosen_class).lightened(0.3))

    if not chosen_valid:
        var vtext := ""
        if last_trial_deck_idx >= 0 and last_trial_deck_idx < deck_slots.size():
            vtext = _slot_validation_text(deck_slots[last_trial_deck_idx])
        label(vtext if vtext != "" else "Invalid deck.", Vector2(16, 264), Vector2(455, 60), 13, info).add_theme_color_override("font_color", Color(1.0, 0.55, 0.5))

    var trial_start_btn := button("START TRIAL", Vector2(100, 418), Vector2(287, 58),
        func(): _do_launch_trial_battle(opponent_class, tier, last_trial_deck_idx), info)
    trial_start_btn.disabled = not chosen_valid
    if not chosen_valid:
        trial_start_btn.add_theme_stylebox_override("disabled", style(Color(0.22, 0.22, 0.28), 10))

    button("MY DECKS", Vector2(100, 360), Vector2(287, 48), show_deck_manager, info)
    button("BACK", Vector2(28, 662), Vector2(160, 42), show_home)

func _build_trial_deck_row(deck_name: String, deck_class: String, card_count: int, valid: bool, selected: bool) -> Button:
    var row := Button.new()
    row.custom_minimum_size = Vector2(690, 52)
    row.add_theme_font_size_override("font_size", 14)
    var row_style := StyleBoxFlat.new()
    if selected:
        row_style.bg_color = class_color(deck_class).darkened(0.2)
        row_style.border_color = GOLD_COLOR
        row_style.set_border_width_all(2)
    else:
        row_style.bg_color = Color(0.10, 0.13, 0.20)
        row_style.border_color = class_color(deck_class).darkened(0.3)
        row_style.set_border_width_all(1)
    row_style.set_corner_radius_all(8)
    row.add_theme_stylebox_override("normal", row_style)
    row.text = "  %s  •  %s  •  %d/40  •  %s" % [
        deck_class.to_upper(), deck_name, card_count, "VALID ✓" if valid else "INVALID ✗"]
    row.add_theme_color_override("font_color", GOLD_COLOR if valid else Color(0.8, 0.5, 0.5))
    return row

func count_in_deck(id: String) -> int:
    var total:=0
    for entry in saved_deck:
        if str(entry)==id: total+=1
    return total

func deck_validation_text() -> String:
    if saved_deck.size() != 40:
        return "Deck needs exactly 40 cards (%d/40)." % saved_deck.size()
    for id in saved_deck:
        var cd := card_by_id(str(id))
        if cd.is_empty():
            return "Unknown card found."
        var card_class := str(cd["class"])
        if card_class != selected_deck_class and card_class != "Neutral":
            return "Wrong class card: %s" % str(cd["name"])
        if count_in_deck(str(id)) > int(COPY_LIMITS.get(str(cd["rarity"]), 1)):
            return "Copy limit exceeded: %s" % str(cd["name"])
    return "DECK VALID — EXACTLY 40 CARDS"

func card_by_id(id: String) -> Dictionary:
    for cd in cards:
        if str(cd["id"])==id: return cd
    return {}

func unique_collected() -> int:
    var total:=0
    for id in collection_owned.keys():
        if int(collection_owned[id])>0: total+=1
    return total


func show_access_login() -> void:
    clear_screen(); add_background(0.72)
    var p := Panel.new(); p.position=Vector2(300,120); p.size=Vector2(680,480); p.add_theme_stylebox_override("panel",style(GOLD_COLOR,18)); root_layer.add_child(p)
    centered_label("AUTHORIZED ACCESS",Vector2(50,34),Vector2(580,52),32,p).add_theme_color_override("font_color",GOLD_COLOR)
    centered_label("Enter the owner PIN to unlock the private test tools. Access closes when the app is restarted or you sign out.",Vector2(75,105),Vector2(530,90),18,p)
    access_token_input = LineEdit.new()
    access_token_input.position = Vector2(110,225)
    access_token_input.size = Vector2(460,52)
    access_token_input.placeholder_text = "Enter 4-digit owner PIN"
    access_token_input.secret = true
    access_token_input.max_length = 4
    access_token_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
    access_token_input.add_theme_font_size_override("font_size",18)
    p.add_child(access_token_input)
    access_status = centered_label("",Vector2(85,292),Vector2(510,56),17,p)
    button("UNLOCK OWNER TOOLS",Vector2(185,360),Vector2(310,56),func(): AccessManager.authenticate(access_token_input.text),p)
    button("BACK",Vector2(260,425),Vector2(160,38),show_home,p)

func _on_access_authentication_finished(success: bool, message: String) -> void:
    if access_status != null and is_instance_valid(access_status):
        access_status.text = message
        access_status.add_theme_color_override("font_color", Color(0.55,1.0,0.70) if success else Color(1.0,0.55,0.55))
    if success:
        await get_tree().create_timer(0.8).timeout
        show_test_tools()

func show_test_tools() -> void:
    if not AccessManager.role_at_least(AccessManager.ROLE_TESTER):
        show_access_login()
        return
    clear_screen(); add_background(0.64)
    header("TEST TOOLS", "%s role • Session-only access" % AccessManager.current_role.capitalize())
    var p := Panel.new(); p.position=Vector2(130,135); p.size=Vector2(1020,515); p.add_theme_stylebox_override("panel",style(Color(0.62,0.42,0.95),18)); root_layer.add_child(p)
    centered_label("TESTER SANDBOX",Vector2(40,24),Vector2(940,48),28,p).add_theme_color_override("font_color",Color(0.78,0.68,1.0))
    centered_label("Sandbox actions never alter a player's permanent collection or economy unless an Owner deliberately uses an Owner-only command.",Vector2(120,78),Vector2(780,72),17,p)
    if AccessManager.role_at_least(AccessManager.ROLE_OWNER):
        centered_label("DEVELOPER META GAUNTLET — OWNER ONLY",Vector2(40,150),Vector2(940,32),18,p).add_theme_color_override("font_color",GOLD_COLOR)
        var meta_classes := ["Hope","Courage","Serenity","Purpose"]
        for i in range(meta_classes.size()):
            var c := str(meta_classes[i])
            button("%s META DECK" % c.to_upper(),Vector2(40+i*238,195),Vector2(220,52),func(): start_developer_meta_battle(c),p)
        button("FINAL BOSS — ALL CLASSES",Vector2(315,255),Vector2(390,48),start_developer_final_boss_battle,p)
    else:
        centered_label("Developer decks require Owner access.",Vector2(40,170),Vector2(940,48),18,p)
    button("OPEN DECK BUILDER",Vector2(110,315),Vector2(350,58),show_deck_builder,p)
    button("VIEW COLLECTION",Vector2(560,315),Vector2(350,58),show_collection,p)
    button("STANDARD TEST BATTLE",Vector2(110,385),Vector2(350,58),start_battle,p)
    button("AUDIO / DEVICE TEST",Vector2(560,385),Vector2(350,58),show_mobile_info,p)
    if AccessManager.role_at_least(AccessManager.ROLE_OWNER):
        var owner_note := centered_label("OWNER CONTROLS",Vector2(40,340),Vector2(940,36),22,p)
        owner_note.add_theme_color_override("font_color",GOLD_COLOR)
        button("ADD 500 TEST GOLD",Vector2(110,390),Vector2(350,52),func():
            gold_balance += 500
            save_profile()
            show_test_tools()
        ,p)
        button("ADD 5 TEST PACKS",Vector2(560,390),Vector2(350,52),func():
            pack_inventory += 5
            save_profile()
            show_test_tools()
        ,p)
    button("SIGN OUT",Vector2(430,460),Vector2(160,38),func():
        AccessManager.sign_out()
        show_home()
    ,p)

func show_mobile_info() -> void:
    clear_screen()
    add_background(0.64)
    header("AUDIO / DEVICE TEST", "RC diagnostics for phones, tablets, desktop, and sound")

    var panel := Panel.new()
    panel.position = Vector2(170, 135)
    panel.size = Vector2(940, 500)
    panel.add_theme_stylebox_override("panel", style(Color(0.30, 0.68, 0.95), 18))
    root_layer.add_child(panel)

    centered_label("DEVICE", Vector2(35, 24), Vector2(410, 36), 23, panel)
    var device_text := "Platform: %s\nScreen: %d × %d\nTouchscreen available: %s\nBuild: %s" % [
        OS.get_name(),
        int(get_viewport_rect().size.x),
        int(get_viewport_rect().size.y),
        "Yes" if DisplayServer.is_touchscreen_available() else "No",
        APP_VERSION
    ]
    centered_label(device_text, Vector2(35, 70), Vector2(410, 150), 17, panel)

    centered_label("AUDIO", Vector2(495, 24), Vector2(410, 36), 23, panel)
    centered_label("Use these checks before exporting the APK.", Vector2(495, 70), Vector2(410, 44), 17, panel)

    button("TEST BUTTON SOUND", Vector2(525, 132), Vector2(350, 48), func():
        if has_node("/root/AudioManager"):
            var audio_manager := get_node_or_null("/root/AudioManager")
            if is_instance_valid(audio_manager) and audio_manager.has_method("play_ui"):
                audio_manager.call("play_ui")
        else:
            academy_feedback_text("Audio manager is not loaded in this scene.", false)
    , panel)

    button("TEST BATTLE", Vector2(525, 196), Vector2(350, 48), start_battle, panel)
    button("TEST CARD VIEW", Vector2(525, 260), Vector2(350, 48), show_collection, panel)

    var checklist := "PRE-APK CHECK\n• Buttons fit within the safe area\n• Touch taps do not double-trigger\n• Music loops without stacking\n• Card text remains readable\n• Back navigation returns safely"
    centered_label(checklist, Vector2(55, 245), Vector2(390, 175), 16, panel)

    button("BACK TO TEST TOOLS", Vector2(310, 435), Vector2(320, 42), show_test_tools, panel)

# ── Sleeve system ─────────────────────────────────────────────────────────────

func _sleeve_catalog() -> Array:
    return [
        {"id":"hope_dawn",      "name":"Dawn's Promise",    "class":"Hope",      "rarity":"Standard", "cost":0,   "pullable":false, "desc":"The original Hope sleeve."},
        {"id":"courage_flame",  "name":"Flame Unbound",     "class":"Courage",   "rarity":"Standard", "cost":0,   "pullable":false, "desc":"The original Courage sleeve."},
        {"id":"serenity_wave",  "name":"Still Waters",      "class":"Serenity",  "rarity":"Standard", "cost":0,   "pullable":false, "desc":"The original Serenity sleeve."},
        {"id":"purpose_compass","name":"True North",        "class":"Purpose",   "rarity":"Standard", "cost":0,   "pullable":false, "desc":"The original Purpose sleeve."},
        {"id":"hope_midnight",  "name":"Midnight Star",     "class":"Hope",      "rarity":"Rare",     "cost":750, "pullable":true,  "desc":"A moonlit variant for Hope leaders."},
        {"id":"courage_storm",  "name":"Storm's Eye",       "class":"Courage",   "rarity":"Rare",     "cost":750, "pullable":true,  "desc":"Electric fury for Courage leaders."},
        {"id":"serenity_jade",  "name":"Jade Tranquil",     "class":"Serenity",  "rarity":"Rare",     "cost":750, "pullable":true,  "desc":"Nature's peace for Serenity leaders."},
        {"id":"purpose_sovereign","name":"Sovereign Seal",  "class":"Purpose",   "rarity":"Rare",     "cost":750, "pullable":true,  "desc":"Ornate gold for Purpose leaders."},
        {"id":"dawn_unity",     "name":"Unity of Dawn",     "class":"Universal", "rarity":"Legendary","cost":0,   "pullable":true,  "desc":"All four classes united. Pack-exclusive."},
        {"id":"sponsor",        "name":"The Sponsor's Shadow","class":"Universal","rarity":"Legendary","cost":0,  "pullable":false, "desc":"Earned by defeating The Sponsor in Trials."},
    ]

func sleeve_owned(sleeve_id: String) -> bool:
    match sleeve_id:
        "hope_dawn", "courage_flame", "serenity_wave", "purpose_compass":
            return true  # Default class sleeves are always free.
        "sponsor":
            return sponsor_sleeve_unlocked
    return owned_sleeves.has(sleeve_id)

func _sleeve_name_for_id(sleeve_id: String) -> String:
    for s in _sleeve_catalog():
        if s["id"] == sleeve_id:
            return s["name"]
    return sleeve_id

func _sleeve_class_color(sleeve_class: String) -> Color:
    match sleeve_class:
        "Hope":      return Color(0.72, 0.45, 1.0)
        "Courage":   return Color(1.0,  0.34, 0.20)
        "Serenity":  return Color(0.26, 0.78, 0.94)
        "Purpose":   return Color(0.95, 0.68, 0.22)
        "Universal": return Color(0.88, 0.88, 0.88)
    return Color(0.55, 0.82, 0.58)

func _sleeve_rarity_color(rarity: String) -> Color:
    match rarity:
        "Legendary": return Color(0.95, 0.78, 0.20)
        "Rare":      return Color(0.45, 0.72, 1.0)
    return Color(0.72, 0.72, 0.72)

func show_sleeves() -> void:
    clear_screen(); add_background(0.80)
    header("CARD SLEEVES", "Equip a sleeve — it appears on your deck pile and enemy eyes it in battle")
    currency_bar()

    var catalog := _sleeve_catalog()
    var cols := 5
    var cell_w := 202.0
    var cell_h := 258.0
    var pad_x := (1280.0 - cols * cell_w) * 0.5
    var pad_y := 150.0

    for si in range(catalog.size()):
        var slv: Dictionary = catalog[si]
        var col := si % cols
        var row := si / cols
        var cx := pad_x + col * cell_w
        var cy := pad_y + row * cell_h

        var owned := sleeve_owned(slv["id"])
        var is_equipped: bool = equipped_sleeve == str(slv["id"]) or (equipped_sleeve == "" and str(slv["id"]) == _default_sleeve_for_class())
        var ac := _sleeve_class_color(slv.get("class", "Universal"))
        var rc := _sleeve_rarity_color(slv.get("rarity", "Standard"))

        # Cell background
        var cell := Panel.new()
        cell.position = Vector2(cx, cy); cell.size = Vector2(cell_w - 8, cell_h - 8)
        var cs := StyleBoxFlat.new()
        cs.bg_color = Color(ac.r * 0.06, ac.g * 0.06, ac.b * 0.10, 0.95)
        cs.border_color = rc if is_equipped else Color(ac.r * 0.55, ac.g * 0.55, ac.b * 0.70, 0.75)
        cs.set_border_width_all(2 if not is_equipped else 3)
        cs.set_corner_radius_all(10)
        cell.add_theme_stylebox_override("panel", cs)
        root_layer.add_child(cell)

        # Sleeve preview using CardView
        var preview := CardView.new()
        preview.setup({}, 0, false, true, slv["id"])
        preview.scale = Vector2(0.52, 0.52)
        preview.position = Vector2(((cell_w - 8) - 142.0 * 0.52) * 0.5, 8)
        preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
        if not owned:
            preview.modulate = Color(1, 1, 1, 0.38)
        cell.add_child(preview)

        # Rarity badge
        var rarity_lbl := Label.new()
        rarity_lbl.text = slv.get("rarity", "Standard").to_upper()
        rarity_lbl.position = Vector2(0, 108); rarity_lbl.size = Vector2(cell_w - 8, 18)
        rarity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        rarity_lbl.add_theme_font_size_override("font_size", 11)
        rarity_lbl.add_theme_color_override("font_color", rc)
        cell.add_child(rarity_lbl)

        # Sleeve name
        var name_lbl := Label.new()
        name_lbl.text = slv["name"]
        name_lbl.position = Vector2(4, 126); name_lbl.size = Vector2(cell_w - 16, 22)
        name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        name_lbl.add_theme_font_size_override("font_size", 13)
        name_lbl.add_theme_color_override("font_color", Color.WHITE if owned else Color(0.55, 0.55, 0.55))
        cell.add_child(name_lbl)

        # Class label
        var class_lbl := Label.new()
        class_lbl.text = slv.get("class", "Universal")
        class_lbl.position = Vector2(4, 146); class_lbl.size = Vector2(cell_w - 16, 18)
        class_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        class_lbl.add_theme_font_size_override("font_size", 11)
        class_lbl.add_theme_color_override("font_color", ac)
        cell.add_child(class_lbl)

        # Action button
        var btn_y := 170.0
        var btn_h := 34.0
        var btn_w := cell_w - 24.0
        var btn_x := 8.0
        if is_equipped:
            var eq_lbl := Label.new()
            eq_lbl.text = "✓ EQUIPPED"
            eq_lbl.position = Vector2(btn_x, btn_y); eq_lbl.size = Vector2(btn_w, btn_h)
            eq_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
            eq_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
            eq_lbl.add_theme_font_size_override("font_size", 13)
            eq_lbl.add_theme_color_override("font_color", Color(0.55, 1.0, 0.55))
            cell.add_child(eq_lbl)
        elif owned:
            var equip_id: String = str(slv["id"])
            var btn := button("EQUIP", Vector2(cx + btn_x, cy + btn_y), Vector2(btn_w, btn_h), func():
                equipped_sleeve = equip_id; save_profile(); show_sleeves())
            btn.reparent(root_layer)
            btn.position = Vector2(cx + btn_x, cy + btn_y)
        elif slv.get("cost", 0) > 0:
            var cost: int = slv["cost"]
            var buy_id: String = str(slv["id"])
            var can_buy: bool = gold_balance >= cost
            var btn := button("%d GOLD" % cost, Vector2(cx + btn_x, cy + btn_y), Vector2(btn_w, btn_h), func():
                if gold_balance < cost: return
                gold_balance -= cost; owned_sleeves.append(buy_id); save_profile(); show_sleeves())
            btn.reparent(root_layer)
            btn.position = Vector2(cx + btn_x, cy + btn_y)
            if not can_buy:
                btn.modulate = Color(0.55, 0.55, 0.55)
        else:
            var locked_lbl := Label.new()
            locked_lbl.text = "PACK ONLY" if slv.get("pullable", false) else "TRIAL REWARD"
            locked_lbl.position = Vector2(btn_x, btn_y); locked_lbl.size = Vector2(btn_w, btn_h)
            locked_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
            locked_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
            locked_lbl.add_theme_font_size_override("font_size", 11)
            locked_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
            cell.add_child(locked_lbl)

    button("BACK", Vector2(20, 670), Vector2(120, 38), show_store)

func _default_sleeve_for_class() -> String:
    match selected_class:
        "Hope":     return "hope_dawn"
        "Courage":  return "courage_flame"
        "Serenity": return "serenity_wave"
        "Purpose":  return "purpose_compass"
    return ""

# ── First-login starter deck choice ──────────────────────────────────────────
# Shown exactly once per account, immediately after the player's first login.
# The player picks one of the four class starter decks; on confirm the 40-card
# deck is granted, a named deck slot is created, and the choice is saved to
# both local disk and Supabase before navigation proceeds to the home screen.
#
# Design rules:
#  • No developer/meta/final-boss/test cards are granted — only the same cards
#    build_starter_deck() produces from starter_recipe().
#  • No full-collection grant — only the 40 starter cards.
#  • Existing players skip this entirely (migration in load_profile sets the
#    flag if collection_owned or deck_slots is non-empty).
#  • Guest players (no user_id) also skip this gate in show_home().

func show_starter_deck_choice() -> void:
    clear_screen(); add_background(0.72)
    ensure_home_music()
    header("CHOOSE YOUR STARTER DECK",
        "Pick the class that speaks to you — you'll receive its full 40-card deck to start")

    # Per-class content displayed on each panel.
    var class_strategies := {
        "Hope":     ["Heal your leader to stay in the fight",
                     "Recover fallen followers from the Relapse Zone",
                     "Draw cards and outlast any opponent"],
        "Courage":  ["Rush followers onto the board immediately",
                     "Attack the enemy leader directly to build Resolve",
                     "Overwhelm with speed and relentless pressure"],
        "Serenity": ["Guard your leader with Protector followers",
                     "Freeze strong enemies and control the board",
                     "Outlast and out-value with healing and patience"],
        "Purpose":  ["Spend all your Play Points to earn Progress",
                     "Ramp up maximum PP for powerful late-game cards",
                     "Unleash Walking Free to dominate with finishers"]
    }
    var class_mechanics := {
        "Hope":     "Recovery • Final Breath • Healing",
        "Courage":  "Rush • Charge • Breakthrough",
        "Serenity": "Protector • Exhaust • Calm",
        "Purpose":  "Progress • PP Ramp • Evolution"
    }

    # Shared state dictionary boxes the selection so closures can see updates.
    # (GDScript closures capture by value for locals; a Dictionary reference
    # lets every callback see the latest selected class and widget handles.)
    var state := {
        "selected":      "",
        "confirm_btn":   null,
        "confirm_label": null,
        "panels":        {}
    }

    for i in range(CLASSES.size()):
        var c: String = CLASSES[i]
        var accent := class_color(c)

        var outer := Panel.new()
        outer.position = Vector2(32 + i * 312, 102)
        outer.size = Vector2(288, 492)
        outer.add_theme_stylebox_override("panel", style(accent, 18))
        root_layer.add_child(outer)
        state["panels"][c] = outer

        # Leader portrait (top 45% of panel)
        var art := TextureRect.new()
        art.texture = class_leader_texture(c)
        art.position = Vector2(22, 16)
        art.size = Vector2(244, 202)
        art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
        art.clip_contents = true
        art.mouse_filter = Control.MOUSE_FILTER_IGNORE
        outer.add_child(art)

        # Class name
        var class_lbl := centered_label(c.to_upper(),
            Vector2(16, 224), Vector2(256, 36), 24, outer)
        class_lbl.add_theme_color_override("font_color", accent.lightened(0.30))
        class_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE

        # Strategy bullets (3 short lines)
        var bullets: Array = class_strategies.get(c, [])
        for bi in range(bullets.size()):
            var bl := label("• " + str(bullets[bi]),
                Vector2(20, 268 + bi * 28), Vector2(248, 26), 13, outer)
            bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
            bl.mouse_filter = Control.MOUSE_FILTER_IGNORE

        # Key mechanics line
        var mech_lbl := centered_label(str(class_mechanics.get(c, "")),
            Vector2(20, 360), Vector2(248, 24), 12, outer)
        mech_lbl.add_theme_color_override("font_color", GOLD_COLOR)
        mech_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE

        # "Preview Deck" opens the standard deck-preview screen; "Back" rebuilds
        # the starter choice screen so the player can still change their mind.
        var cc := c  # capture-safe copy for closures
        button("PREVIEW DECK", Vector2(24, 394), Vector2(240, 38),
            func(): _show_starter_deck_preview(cc, state), outer)

        # "Select" highlights this panel and arms the confirm button.
        button("SELECT THIS DECK", Vector2(24, 444), Vector2(240, 40),
            func(): _select_starter_deck(cc, state), outer)

    # Global confirm button — disabled until a panel is selected.
    var confirm := button("CONFIRM CHOICE",
        Vector2(490, 612), Vector2(300, 50),
        func(): _confirm_starter_deck_choice(state))
    confirm.disabled = true
    state["confirm_btn"] = confirm

    # Feedback label for cloud-save status (error or progress messages).
    var fb := label("", Vector2(200, 670), Vector2(880, 28), 15)
    fb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    fb.add_theme_color_override("font_color", Color(1.0, 0.65, 0.35))
    state["confirm_label"] = fb

    # "Build For Me" link — alternative path to auto-build without selecting
    # a starter from this screen.  Sits below the confirm button row.
    var bfm := button("✦ Build a deck from my cards instead →",
        Vector2(395, 700), Vector2(490, 34),
        func(): show_auto_build_class_select(true))
    bfm.add_theme_font_size_override("font_size", 13)
    bfm.add_theme_stylebox_override("normal", style(Color(0.20, 0.30, 0.48), 8))
    bfm.add_theme_color_override("font_color", Color(0.62, 0.82, 1.0))


## Highlight the chosen panel and arm the confirm button for the given class.
func _select_starter_deck(c: String, state: Dictionary) -> void:
    state["selected"] = c
    # Update all panel borders: selected = white border + slightly lightened bg;
    # others = normal class-coloured style.
    for cls in state["panels"].keys():
        var panel: Panel = state["panels"][cls]
        if not is_instance_valid(panel):
            continue
        if cls == c:
            var s := StyleBoxFlat.new()
            s.bg_color = class_color(cls).lerp(Color.WHITE, 0.14)
            s.border_width_top    = 4; s.border_width_bottom = 4
            s.border_width_left   = 4; s.border_width_right  = 4
            s.border_color = Color(1, 1, 1, 0.90)
            s.corner_radius_top_left     = 18; s.corner_radius_top_right    = 18
            s.corner_radius_bottom_left  = 18; s.corner_radius_bottom_right = 18
            panel.add_theme_stylebox_override("panel", s)
        else:
            panel.add_theme_stylebox_override("panel", style(class_color(cls), 18))
    # Arm the confirm button and label it with the chosen class.
    var confirm_btn: Button = state.get("confirm_btn")
    if is_instance_valid(confirm_btn):
        confirm_btn.disabled = false
        confirm_btn.text = "CLAIM %s DECK ✓" % c.to_upper()
    # Clear any leftover feedback text from a previous attempt.
    var fb: Label = state.get("confirm_label")
    if is_instance_valid(fb):
        fb.text = ""


## Open the standard prebuilt deck-preview screen for class c, then add a
## "Back to deck choice" button so the player can return and change their mind.
func _show_starter_deck_preview(c: String, state: Dictionary) -> void:
    _show_battle_deck_preview(c, "prebuilt", false)
    # Re-add a back button over the preview screen's normal HOME button area.
    button("← BACK TO DECK CHOICE", Vector2(28, 650), Vector2(280, 48),
        func(): show_starter_deck_choice())


## Grant the chosen starter deck, persist to disk + Supabase, then go home.
## This is an async function: it awaits the cloud upload before navigating.
func _confirm_starter_deck_choice(state: Dictionary) -> void:
    var chosen_class: String = str(state.get("selected", ""))
    if chosen_class.is_empty() or not (chosen_class in CLASSES):
        return
    # Double-click / double-call guard.
    if starter_deck_selected:
        print("STARTER DECK: already selected, skipping re-grant and going home")
        show_home()
        return

    # Disable the button and show a saving indicator immediately so the player
    # knows the confirm tap was registered even on a slow connection.
    var confirm_btn: Button = state.get("confirm_btn")
    var feedback_label: Label = state.get("confirm_label")
    if is_instance_valid(confirm_btn):
        confirm_btn.disabled = true
    safe_set_text(feedback_label, "Saving your starter deck…")
    print("STARTER DECK: confirm pressed, class=%s user=%s" % [chosen_class, NetworkManager.user_id])

    # ── Grant the deck ───────────────────────────────────────────────────────
    # build_starter_deck() only adds the 40 specific starter-recipe card IDs to
    # collection_owned — it does NOT run grant_starter_collection(), so the
    # player is not given every single class card.  No dev/meta/test cards.
    selected_class      = chosen_class
    selected_deck_class = chosen_class
    build_starter_deck(chosen_class)

    # Assert the recipe is exactly 40 cards and contains no owner/dev cards.
    # This fires a logged error in debug builds if the content ever drifts.
    if saved_deck.size() != 40:
        push_error("STARTER DECK: deck has %d cards instead of 40 — check starter_recipe()" % saved_deck.size())

    # Create a named deck slot at position 0 so the starter shows up first in
    # the deck list.  If a slot already exists for this class (duplicate guard),
    # update it in place instead of appending.
    var slot_idx := -1
    for si in range(deck_slots.size()):
        if str(deck_slots[si].get("name", "")) == "My %s Starter" % chosen_class:
            slot_idx = si
            break
    var slot_dict := {
        "name":  "My %s Starter" % chosen_class,
        "class": chosen_class,
        "cards": saved_deck.duplicate()
    }
    if slot_idx >= 0:
        deck_slots[slot_idx] = slot_dict
        last_battle_deck_idx = slot_idx
    else:
        deck_slots.insert(0, slot_dict)
        last_battle_deck_idx = 0

    # Set the flag before saving so both the local file and cloud record it.
    starter_deck_selected = true

    # ── Persist locally and queue a cloud sync ───────────────────────────────
    # save_profile() writes to disk immediately (synchronous), then calls
    # _queue_cloud_upload.call_deferred(), which routes through the established
    # safety model: it checks _cloud_safe_to_upload and the integrity guard
    # before touching Supabase.  We never bypass those checks here.
    #
    # If the cloud fetch hasn't completed yet (e.g. the player confirmed during
    # the brief window between auth success and the save_data callback), the
    # deferred upload will be blocked by _cloud_safe_to_upload = false.  That
    # is correct and intentional: the local save is the record of truth in that
    # case; the cloud will be updated on the next successful fetch-and-merge.
    save_profile()
    print("STARTER DECK: local save written, class=%s deck_size=%d collection=%d cloud_safe=%s" % [
        chosen_class, saved_deck.size(), collection_owned.size(), str(_cloud_safe_to_upload)])

    # ── Navigate home ────────────────────────────────────────────────────────
    show_home()


# ═══════════════════════════════════════════════════════════════════════════════
# AUTO-BUILD DECK
# ═══════════════════════════════════════════════════════════════════════════════
#
# Entry points:
#   • Deck builder — "✦ AUTO-BUILD DECK" button in _build_db_deck_panel
#   • First-login onboarding — "Build a deck from my cards instead →" link in
#     show_starter_deck_choice
#
# Flow:
#   show_auto_build_class_select(from_onboarding)
#       ↓ class button                     ↓ "Recommend a Class"
#   show_auto_build_preview(...)     _show_auto_build_recommend(from_onboarding)
#       ↓ Accept / Regenerate / Cancel          ↓ click a class description
#   _accept_auto_built_deck(...)     show_auto_build_preview(...)
# ═══════════════════════════════════════════════════════════════════════════════

## Generate a 40-card deck for class [c] using only the player's owned cards.
##
## Algorithm:
##   1. Build a pool of (id, cost, allowed_copies) from collection_owned,
##      filtered to the target class + Neutral/Universal, excluding FORBIDDEN.
##   2. If total available slots < 40, fall back to starter_recipe().
##   3. Sort pool: cost ascending, then by random order (seeded for variety).
##   4. Fill 40 slots greedily from the sorted pool.
##
## [rng_seed] < 0 → randomize (every Regenerate press produces a new deck).
## [rng_seed] ≥ 0 → reproduce a specific result (e.g. for testing).
##
## Returns: { "deck": Array[String], "fallback": bool }
##   fallback = true  → not enough owned cards; deck is the starter_recipe instead.
func _auto_build_deck(c: String, rng_seed: int = -1) -> Dictionary:
    var rng := RandomNumberGenerator.new()
    if rng_seed < 0:
        rng.randomize()
    else:
        rng.seed = rng_seed

    # ── 1. Candidate pool ────────────────────────────────────────────────────
    var pool: Array = []
    for cd in cards:
        var card_class := str(cd.get("class", ""))
        if card_class != c and card_class != "Neutral" and card_class != "Universal":
            continue
        var id := str(cd.get("id", ""))
        if id in AUTO_BUILD_FORBIDDEN_IDS:
            continue
        var owned := int(collection_owned.get(id, 0))
        if owned <= 0:
            continue
        var rarity := str(cd.get("rarity", "Bronze"))
        var copy_limit := int(COPY_LIMITS.get(rarity, 3))
        # Per-card max_copies from the catalog may be tighter than the rarity default.
        var json_max_raw: Variant = cd.get("max_copies", null)
        var json_max: int
        if json_max_raw == null:
            json_max = copy_limit
        else:
            var jm := int(json_max_raw)
            json_max = jm if jm > 0 else copy_limit
        var allowed := mini(mini(copy_limit, json_max), owned)
        if allowed <= 0:
            continue
        pool.append({
            "id":        id,
            "cost":      int(cd.get("cost", 0)),
            "rng_order": rng.randi(),
            "allowed":   allowed
        })

    # ── 2. Capacity check ────────────────────────────────────────────────────
    var total_available := 0
    for entry in pool:
        total_available += int(entry["allowed"])
    if total_available < 40:
        # Not enough owned cards — build from the starter recipe instead.
        var recipe := starter_recipe(c)
        var fallback_deck: Array = []
        for fid in recipe.keys():
            for _fi in range(int(recipe[fid])):
                fallback_deck.append(str(fid))
        print("AUTO-BUILD: fallback for class=%s owned_slots=%d" % [c, total_available])
        return {"deck": fallback_deck, "fallback": true}

    # ── 3. Sort: cost ascending, random within each cost bucket ─────────────
    pool.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        if int(a["cost"]) != int(b["cost"]):
            return int(a["cost"]) < int(b["cost"])
        return int(a["rng_order"]) < int(b["rng_order"])
    )

    # ── 4. Fill 40 slots ─────────────────────────────────────────────────────
    var result: Array = []
    for entry in pool:
        var to_add := mini(int(entry["allowed"]), 40 - result.size())
        for _j in range(to_add):
            result.append(str(entry["id"]))
        if result.size() >= 40:
            break

    print("AUTO-BUILD: class=%s built %d cards from owned pool" % [c, result.size()])
    return {"deck": result, "fallback": false}


## Class-selection screen — first step of the Auto-Build flow.
## Shows 4 class option buttons and a "Recommend a Class" button.
## [from_onboarding] is forwarded through the whole flow so the final Accept
## knows whether to finish the first-login sequence or return to deck builder.
func show_auto_build_class_select(from_onboarding: bool) -> void:
    clear_screen(); add_background(0.72)
    ensure_home_music()

    header("AUTO-BUILD DECK",
        "Pick a class — the engine builds a legal 40-card deck from your owned cards")

    # 2×2 class grid
    for idx in range(CLASSES.size()):
        var c: String = CLASSES[idx]
        var accent := class_color(c)
        var col := idx % 2
        var row := idx / 2
        var px := 30 + col * 366
        var py := 118 + row * 192

        var panel := Panel.new()
        panel.position = Vector2(px, py); panel.size = Vector2(344, 176)
        panel.add_theme_stylebox_override("panel", style(accent, 12))
        root_layer.add_child(panel)

        # Class name
        var nl := Label.new()
        nl.text = c.to_upper()
        nl.position = Vector2(14, 10); nl.size = Vector2(314, 32)
        nl.add_theme_font_size_override("font_size", 22)
        nl.add_theme_color_override("font_color", accent.lightened(0.30))
        nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
        panel.add_child(nl)

        # One-line keyword teaser
        var teasers := {
            "Hope":     "Healing · Recovery · Draw",
            "Courage":  "Rush · Charge · Direct Damage",
            "Serenity": "Protector · Exhaust · Board Control",
            "Purpose":  "Progress · PP Ramp · Late Game"
        }
        var tl := Label.new()
        tl.text = str(teasers.get(c, ""))
        tl.position = Vector2(14, 48); tl.size = Vector2(314, 22)
        tl.add_theme_font_size_override("font_size", 13)
        tl.add_theme_color_override("font_color", GOLD_COLOR)
        tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
        panel.add_child(tl)

        # Cards-owned count (class cards + neutral, already in collection)
        var owned_cnt := 0
        for cd in cards:
            var cc2: String = str(cd.get("class", ""))
            if cc2 == c or cc2 == "Neutral" or cc2 == "Universal":
                if int(collection_owned.get(str(cd.get("id", "")), 0)) > 0:
                    owned_cnt += 1
        var oc_lbl := Label.new()
        oc_lbl.text = "%d owned cards available" % owned_cnt
        oc_lbl.position = Vector2(14, 76); oc_lbl.size = Vector2(314, 22)
        oc_lbl.add_theme_font_size_override("font_size", 12)
        oc_lbl.add_theme_color_override("font_color", Color(0.62, 0.62, 0.74))
        oc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
        panel.add_child(oc_lbl)

        # BUILD button — runs algorithm and goes straight to preview
        var cc3 := c  # closure-safe copy
        button("BUILD %s DECK" % c.to_upper(), Vector2(14, 108), Vector2(314, 46),
            func():
                var res := _auto_build_deck(cc3)
                show_auto_build_preview(cc3, res["deck"], res["fallback"], from_onboarding, -1),
            panel)

    # Recommend a Class — opens descriptions page
    var rec_btn := Button.new()
    rec_btn.text = "✦  RECOMMEND A CLASS  ✦"
    rec_btn.position = Vector2(30, 520); rec_btn.size = Vector2(660, 50)
    rec_btn.add_theme_font_size_override("font_size", 16)
    rec_btn.add_theme_stylebox_override("normal", style(Color(0.24, 0.20, 0.40), 10))
    rec_btn.add_theme_stylebox_override("hover",  style(Color(0.34, 0.28, 0.56), 10))
    rec_btn.pressed.connect(func(): _show_auto_build_recommend(from_onboarding))
    root_layer.add_child(rec_btn)

    # Cancel — return to where we came from
    button("← BACK", Vector2(30, 650), Vector2(160, 44),
        func():
            if from_onboarding:
                show_starter_deck_choice()
            else:
                show_deck_builder())


## "Recommend a Class" descriptions page.
## Shows a one-paragraph playstyle description for each class.
## Clicking any panel immediately runs the algorithm and opens the preview.
func _show_auto_build_recommend(from_onboarding: bool) -> void:
    clear_screen(); add_background(0.72)
    ensure_home_music()
    header("WHICH CLASS IS RIGHT FOR YOU?",
        "Read each style — click the one that sounds like you to build that deck now")

    for idx in range(CLASSES.size()):
        var c: String = CLASSES[idx]
        var accent := class_color(c)
        var col := idx % 2
        var row := idx / 2
        var px := 30 + col * 498
        var py := 112 + row * 220

        var panel := Panel.new()
        panel.position = Vector2(px, py); panel.size = Vector2(472, 204)
        panel.add_theme_stylebox_override("panel", style(accent, 14))
        root_layer.add_child(panel)

        # Class name
        var nl := Label.new()
        nl.text = c.to_upper()
        nl.position = Vector2(16, 10); nl.size = Vector2(440, 32)
        nl.add_theme_font_size_override("font_size", 20)
        nl.add_theme_color_override("font_color", accent.lightened(0.30))
        nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
        panel.add_child(nl)

        # Description paragraph
        var dl := Label.new()
        dl.text = str(AUTO_BUILD_CLASS_BLURBS.get(c, ""))
        dl.position = Vector2(16, 48); dl.size = Vector2(440, 130)
        dl.add_theme_font_size_override("font_size", 12)
        dl.add_theme_color_override("font_color", Color(0.88, 0.88, 0.95))
        dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        dl.mouse_filter = Control.MOUSE_FILTER_IGNORE
        panel.add_child(dl)

        # "Build This Deck" label at bottom of panel
        var hint := Label.new()
        hint.text = "▶ Click to build this deck"
        hint.position = Vector2(16, 180); hint.size = Vector2(440, 18)
        hint.add_theme_font_size_override("font_size", 11)
        hint.add_theme_color_override("font_color", GOLD_COLOR.darkened(0.10))
        hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
        panel.add_child(hint)

        # Invisible full-panel click target
        var cc4 := c
        var click_btn := Button.new()
        click_btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        click_btn.flat = true
        var esb := StyleBoxEmpty.new()
        click_btn.add_theme_stylebox_override("normal", esb)
        click_btn.add_theme_stylebox_override("hover",  esb)
        click_btn.pressed.connect(func():
            var res := _auto_build_deck(cc4)
            show_auto_build_preview(cc4, res["deck"], res["fallback"], from_onboarding, -1))
        panel.add_child(click_btn)

    button("← BACK", Vector2(30, 650), Vector2(160, 44),
        func(): show_auto_build_class_select(from_onboarding))


## Preview the auto-built deck.  Shows the cost curve, the full card list, and
## three action buttons: Accept (save to a new slot), Regenerate (re-run the
## algorithm with a fresh random seed), and Cancel (go back to class select).
func show_auto_build_preview(c: String, deck: Array, is_fallback: bool,
        from_onboarding: bool, _prev_seed: int) -> void:
    clear_screen(); add_background(0.72)
    ensure_home_music()

    var accent := class_color(c)

    # ── Top header bar ───────────────────────────────────────────────────────
    var hp := Panel.new()
    hp.position = Vector2(0, 0); hp.size = Vector2(1280, 82)
    var hs := StyleBoxFlat.new()
    hs.bg_color = Color(0.018, 0.022, 0.040, 1.0)
    hs.set_border_width_all(0); hs.border_width_bottom = 2
    hs.border_color = accent.darkened(0.35)
    hp.add_theme_stylebox_override("panel", hs)
    root_layer.add_child(hp)

    var title_lbl := Label.new()
    title_lbl.text = "%s AUTO-BUILD — PREVIEW" % c.to_upper()
    title_lbl.position = Vector2(24, 8); title_lbl.size = Vector2(700, 36)
    title_lbl.add_theme_font_size_override("font_size", 24)
    title_lbl.add_theme_color_override("font_color", accent.lightened(0.25))
    hp.add_child(title_lbl)

    var built_from := "Built from your owned cards" if not is_fallback else "STARTER RECIPE (not enough owned cards)"
    var sub_lbl := Label.new()
    sub_lbl.text = "%d / 40 cards  •  %s" % [deck.size(), built_from]
    sub_lbl.position = Vector2(24, 50); sub_lbl.size = Vector2(900, 26)
    sub_lbl.add_theme_font_size_override("font_size", 14)
    sub_lbl.add_theme_color_override("font_color", Color(1.0, 0.72, 0.30) if is_fallback else Color(0.62, 0.62, 0.74))
    hp.add_child(sub_lbl)

    # Fallback notice strip
    var content_y := 82
    if is_fallback:
        var nb := Panel.new()
        nb.position = Vector2(0, 82); nb.size = Vector2(1280, 46)
        var ns := StyleBoxFlat.new(); ns.bg_color = Color(0.28, 0.18, 0.06, 0.90)
        nb.add_theme_stylebox_override("panel", ns)
        root_layer.add_child(nb)
        var nl2 := Label.new()
        nl2.text = "⚠  You don't own enough cards for a fully personalised deck yet — showing the %s starter recipe. Accept to apply it, or choose a different class." % c
        nl2.position = Vector2(16, 8); nl2.size = Vector2(1248, 30)
        nl2.add_theme_font_size_override("font_size", 13)
        nl2.add_theme_color_override("font_color", Color(1.0, 0.82, 0.42))
        nl2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        nb.add_child(nl2)
        content_y = 130

    # ── Left panel: cost curve + card list ───────────────────────────────────
    var left_h := 700 - content_y
    var left_panel := Panel.new()
    left_panel.position = Vector2(12, content_y); left_panel.size = Vector2(878, left_h)
    left_panel.add_theme_stylebox_override("panel", style(Color(0.025, 0.035, 0.060), 12))
    root_layer.add_child(left_panel)

    # Mana curve header
    var cl := Label.new(); cl.text = "MANA CURVE"
    cl.position = Vector2(16, 10); cl.size = Vector2(200, 22)
    cl.add_theme_font_size_override("font_size", 13)
    cl.add_theme_color_override("font_color", GOLD_COLOR)
    left_panel.add_child(cl)

    # Mana curve bars (inline — avoids needing a VBox parent)
    var buckets := [0, 0, 0, 0, 0, 0, 0, 0]
    for id in deck:
        var cdd := card_by_id(str(id))
        if cdd.is_empty(): continue
        buckets[mini(int(cdd.get("cost", 0)), 7)] += 1
    var max_b := 1
    for b in buckets:
        if b > max_b: max_b = b
    for i in range(8):
        var cx := 16 + i * 36
        var bar_h := 38
        var fill_h := int(float(buckets[i]) / float(max_b) * bar_h) if max_b > 0 else 0
        var bg := Panel.new()
        bg.position = Vector2(cx, 34); bg.size = Vector2(28, bar_h)
        var bgs := StyleBoxFlat.new(); bgs.bg_color = Color(0.08, 0.10, 0.18)
        bgs.set_corner_radius_all(3); bg.add_theme_stylebox_override("panel", bgs)
        left_panel.add_child(bg)
        if fill_h > 0:
            var fill := Panel.new()
            fill.position = Vector2(0, bar_h - fill_h); fill.size = Vector2(28, fill_h)
            var fs := StyleBoxFlat.new()
            fs.bg_color = Color(0.35, 0.50, 0.92, 0.88).lerp(GOLD_COLOR, float(i) / 7.0)
            fs.set_corner_radius_all(3); fill.add_theme_stylebox_override("panel", fs)
            bg.add_child(fill)
        var cnt_l := Label.new()
        cnt_l.text = str(buckets[i]) if buckets[i] > 0 else ""
        cnt_l.position = Vector2(cx, 74); cnt_l.size = Vector2(28, 18)
        cnt_l.add_theme_font_size_override("font_size", 10)
        cnt_l.add_theme_color_override("font_color", Color(0.68, 0.68, 0.82))
        cnt_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        left_panel.add_child(cnt_l)
        var lbl_c := Label.new()
        lbl_c.text = str(i) if i < 7 else "7+"
        lbl_c.position = Vector2(cx, 94); lbl_c.size = Vector2(28, 16)
        lbl_c.add_theme_font_size_override("font_size", 10)
        lbl_c.add_theme_color_override("font_color", Color(0.44, 0.44, 0.54))
        lbl_c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        left_panel.add_child(lbl_c)

    # Card list (grouped by id, sorted by cost)
    var counts: Dictionary = {}
    for id in deck:
        counts[str(id)] = int(counts.get(str(id), 0)) + 1
    var ordered_ids: Array = counts.keys()
    ordered_ids.sort_custom(func(a: String, b: String) -> bool:
        return int(card_by_id(a).get("cost", 0)) < int(card_by_id(b).get("cost", 0))
    )

    var list_scroll := ScrollContainer.new()
    list_scroll.position = Vector2(12, 118); list_scroll.size = Vector2(854, left_h - 128)
    left_panel.add_child(list_scroll)
    var list_vb := VBoxContainer.new()
    list_vb.add_theme_constant_override("separation", 2)
    list_vb.size_flags_horizontal = Control.SIZE_FILL
    list_scroll.add_child(list_vb)

    for id in ordered_ids:
        var cdd := card_by_id(str(id))
        if cdd.is_empty(): continue
        var row := Panel.new()
        row.custom_minimum_size = Vector2(0, 30)
        row.size_flags_horizontal = Control.SIZE_FILL
        row.add_theme_stylebox_override("panel", style(Color(0.06, 0.08, 0.14), 4))
        list_vb.add_child(row)

        var cost_l := Label.new()
        cost_l.text = str(int(cdd.get("cost", 0)))
        cost_l.position = Vector2(6, 4); cost_l.size = Vector2(22, 22)
        cost_l.add_theme_font_size_override("font_size", 12)
        cost_l.add_theme_color_override("font_color", Color(0.50, 0.72, 1.0))
        cost_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        cost_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
        row.add_child(cost_l)

        var name_l := Label.new()
        name_l.text = str(cdd.get("name", id))
        name_l.position = Vector2(34, 4); name_l.size = Vector2(520, 22)
        name_l.add_theme_font_size_override("font_size", 13)
        name_l.add_theme_color_override("font_color", Color(0.90, 0.90, 1.0))
        name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
        row.add_child(name_l)

        # Rarity colour (replicate rarity_color inline — no dedicated helper exists)
        var rar := str(cdd.get("rarity", "Bronze"))
        var rar_clr := Color(0.75, 0.58, 0.38)   # Bronze default
        match rar:
            "Silver":              rar_clr = Color(0.78, 0.78, 0.82)
            "Gold":                rar_clr = Color(0.95, 0.78, 0.34)
            "Epic":                rar_clr = Color(0.72, 0.42, 0.92)
            "Legendary":           rar_clr = Color(1.0,  0.62, 0.18)
            "Platinum", "Signature Platinum": rar_clr = Color(0.72, 0.92, 1.0)
        var rar_l := Label.new()
        rar_l.text = rar
        rar_l.position = Vector2(560, 4); rar_l.size = Vector2(160, 22)
        rar_l.add_theme_font_size_override("font_size", 11)
        rar_l.add_theme_color_override("font_color", rar_clr)
        rar_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
        row.add_child(rar_l)

        var cnt_l2 := Label.new()
        cnt_l2.text = "×%d" % int(counts[str(id)])
        cnt_l2.position = Vector2(724, 4); cnt_l2.size = Vector2(56, 22)
        cnt_l2.add_theme_font_size_override("font_size", 13)
        cnt_l2.add_theme_color_override("font_color", GOLD_COLOR)
        cnt_l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        cnt_l2.mouse_filter = Control.MOUSE_FILTER_IGNORE
        row.add_child(cnt_l2)

    # ── Right panel: actions ──────────────────────────────────────────────────
    var right_panel := Panel.new()
    right_panel.position = Vector2(904, content_y); right_panel.size = Vector2(364, left_h)
    right_panel.add_theme_stylebox_override("panel", style(Color(0.022, 0.030, 0.052), 12))
    root_layer.add_child(right_panel)

    centered_label("DECK PREVIEW", Vector2(12, 14), Vector2(340, 30), 18, right_panel).add_theme_color_override("font_color", GOLD_COLOR)
    centered_label("%s  •  %d cards" % [c, deck.size()], Vector2(12, 48), Vector2(340, 24), 14, right_panel).add_theme_color_override("font_color", accent.lightened(0.22))

    var btn_y := 84
    if is_fallback:
        var fb_lbl := Label.new()
        fb_lbl.text = "Using starter recipe\n(not enough owned cards to fill 40 slots)"
        fb_lbl.position = Vector2(12, btn_y); fb_lbl.size = Vector2(340, 52)
        fb_lbl.add_theme_font_size_override("font_size", 12)
        fb_lbl.add_theme_color_override("font_color", Color(1.0, 0.72, 0.30))
        fb_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        right_panel.add_child(fb_lbl)
        btn_y += 60

    # Validate the deck inline so the player can see it passes before accepting.
    # Temporarily swap saved_deck / selected_deck_class to reuse the function.
    var orig_deck := saved_deck.duplicate()
    var orig_class := selected_deck_class
    saved_deck = deck.duplicate()
    selected_deck_class = c
    var val_text := deck_validation_text()
    saved_deck = orig_deck
    selected_deck_class = orig_class
    var is_valid := val_text.begins_with("DECK VALID")
    var val_lbl := Label.new()
    val_lbl.text = ("✓  " if is_valid else "⚠  ") + val_text
    val_lbl.position = Vector2(12, btn_y); val_lbl.size = Vector2(340, 48)
    val_lbl.add_theme_font_size_override("font_size", 12)
    val_lbl.add_theme_color_override("font_color", Color(0.40, 1.0, 0.55) if is_valid else Color(1.0, 0.55, 0.40))
    val_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    right_panel.add_child(val_lbl)
    btn_y += 56

    # Accept
    var accept_btn := Button.new()
    accept_btn.text = "✓  ACCEPT DECK"
    accept_btn.position = Vector2(12, btn_y); accept_btn.size = Vector2(340, 54)
    accept_btn.add_theme_font_size_override("font_size", 17)
    accept_btn.add_theme_stylebox_override("normal", style(Color(0.16, 0.50, 0.24), 10))
    accept_btn.add_theme_stylebox_override("hover",  style(Color(0.22, 0.64, 0.30), 10))
    right_panel.add_child(accept_btn)
    accept_btn.pressed.connect(func(): _accept_auto_built_deck(c, deck, is_fallback, from_onboarding))

    # Regenerate (disabled for fallback — the starter recipe is deterministic)
    var regen_btn := Button.new()
    regen_btn.text = "↺  REGENERATE"
    regen_btn.position = Vector2(12, btn_y + 64); regen_btn.size = Vector2(340, 54)
    regen_btn.add_theme_font_size_override("font_size", 17)
    regen_btn.add_theme_stylebox_override("normal", style(Color(0.20, 0.32, 0.54), 10))
    regen_btn.add_theme_stylebox_override("hover",  style(Color(0.28, 0.42, 0.68), 10))
    regen_btn.disabled = is_fallback
    right_panel.add_child(regen_btn)
    regen_btn.pressed.connect(func():
        var r := _auto_build_deck(c)
        show_auto_build_preview(c, r["deck"], r["fallback"], from_onboarding, -1))

    # Cancel
    var cancel_btn := button("✗  CANCEL", Vector2(12, btn_y + 128), Vector2(340, 54),
        func(): show_auto_build_class_select(from_onboarding), right_panel)
    cancel_btn.add_theme_font_size_override("font_size", 17)


## Save the auto-built deck and navigate to the appropriate next screen.
##
## from_onboarding = true  → finish the first-login sequence and go to home.
## from_onboarding = false → append a new deck slot and open it in the builder.
##
## Existing deck slots are NEVER modified — the auto-built deck always creates
## a new named slot, so there is nothing to overwrite.
func _accept_auto_built_deck(c: String, deck: Array, is_fallback: bool, from_onboarding: bool) -> void:
    # ── Slot-capacity guard (deck builder path only) ──────────────────────────
    # Must run BEFORE any state mutation so that a full-slots failure leaves
    # saved_deck / selected_deck_class / saved_decks completely untouched.
    # The onboarding path uses insert(0, …) which always has room because
    # new players start with an empty or very small deck_slots array.
    if not from_onboarding and deck_slots.size() >= MAX_DECK_SLOTS:
        var err := Panel.new()
        err.position = Vector2(280, 220); err.size = Vector2(720, 172)
        err.z_index = 500
        err.add_theme_stylebox_override("panel", style(Color(0.28, 0.08, 0.08), 14))
        root_layer.add_child(err)
        centered_label("DECK SLOTS FULL", Vector2(20, 18), Vector2(680, 36), 22, err).add_theme_color_override("font_color", Color(1.0, 0.55, 0.50))
        var msg_lbl := Label.new()
        msg_lbl.text = "You have %d/%d deck slots. Delete an existing deck first, then come back to Auto-Build." % [deck_slots.size(), MAX_DECK_SLOTS]
        msg_lbl.position = Vector2(40, 68); msg_lbl.size = Vector2(640, 60)
        msg_lbl.add_theme_font_size_override("font_size", 15)
        msg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        err.add_child(msg_lbl)
        button("OK", Vector2(280, 120), Vector2(160, 42), func(): err.queue_free(), err)
        return  # ← no state mutations have occurred above this line

    # ── Mutate runtime state now that we know the save will succeed ───────────
    selected_class      = c
    selected_deck_class = c

    if is_fallback:
        # Use the canonical helper: it handles collection grants + saved_decks sync.
        build_starter_deck(c)
    else:
        saved_deck = deck.duplicate()
        saved_decks[c] = saved_deck.duplicate()

    # ── Generate a unique slot name ──────────────────────────────────────────
    var base_name := "%s – Auto" % c
    var slot_name := base_name
    var suffix := 2
    for existing in deck_slots:
        if str(existing.get("name", "")) == slot_name:
            slot_name = "%s %d" % [base_name, suffix]
            suffix += 1

    var slot_dict := {"name": slot_name, "class": c, "cards": saved_deck.duplicate()}

    if from_onboarding:
        # First-login path: insert at slot 0 so it shows up first.
        deck_slots.insert(0, slot_dict)
        last_battle_deck_idx = 0
        starter_deck_selected = true
        save_profile()
        show_home()
        return

    # Deck builder path — slot capacity was already verified above.
    deck_slots.append(slot_dict)
    editing_deck_slot_idx = deck_slots.size() - 1
    save_profile()
    _open_slot_in_deck_builder(editing_deck_slot_idx)

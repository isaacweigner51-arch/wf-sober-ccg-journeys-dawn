extends Control

const GOLD_COLOR := Color(0.95, 0.78, 0.34)
const PANEL := Color(0.025, 0.045, 0.08, 0.97)
const SAVE_PATH := "user://journeys_dawn_profile.cfg"
const APP_VERSION := "0.5.7"
const BUILD_NAME := "v0.8.4 • AUDIO & CARD ART RECOVERY"
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
const COPY_LIMITS := {"Bronze":3, "Silver":3, "Gold":3, "Epic":3, "Legendary":2, "Platinum":1, "Signature Gold":1, "Signature Platinum":1}
const DUST_VALUES := {"Bronze":10, "Silver":40, "Gold":150, "Epic":275, "Legendary":600, "Platinum":1500, "Signature Platinum":1500}
const CRAFT_COSTS := {"Bronze":50, "Silver":150, "Gold":500, "Epic":900, "Legendary":2000, "Platinum":4500, "Signature Platinum":4500}
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
var selected_class := ""
var collection_owned: Dictionary = {}
var _menu_art_cache: Dictionary = {}
var saved_deck: Array = []
var saved_decks: Dictionary = {}
var recovery_challenge_progress: Dictionary = {}
# The Trials: repeatable PvE gauntlet. trials_cleared keys are "<Class>_<tier>"
# (tier 1-3) or "Sponsor_4" for the bonus boss. Cosmetic rewards are separate
# flags since they persist even if sponsor_defeated bookkeeping ever changes.
var trials_cleared: Dictionary = {}
var sponsor_leader_unlocked := false
var sponsor_sleeve_unlocked := false
var sponsor_defeated := false
var selected_leader_skin := "" # "" (normal) or "sponsor"
var trial_select_class := "Hope"
var selected_deck_class := "Hope"
# Collection screen filter state -- "All" plus the four leader classes plus
# "Neutral" for the class tabs, "All" plus each rarity name for the rarity
# tabs. Kept as instance vars (not locals) so re-opening the screen after a
# craft/dust action remembers what the player was looking at.
var collection_filter_class := "All"
var collection_filter_rarity := "All"
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
var academy_feedback: Label
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
    add_background(0.58)

    var title := centered_label("WF SOBER CCG", Vector2(240, 54), Vector2(800, 62), 42, root_layer)
    title.add_theme_color_override("font_color", GOLD_COLOR)
    centered_label("JOURNEYS DAWN", Vector2(340, 115), Vector2(600, 42), 25, root_layer)
    centered_label("Loading your recovery journey...", Vector2(390, 158), Vector2(500, 30), 16, root_layer).modulate = Color(0.72, 0.82, 0.92)

    var panel := Panel.new()
    panel.position = Vector2(330, 210)
    panel.size = Vector2(620, 430)
    panel.add_theme_stylebox_override("panel", style(GOLD_COLOR, 20))
    root_layer.add_child(panel)

    centered_label("PLAYER ACCOUNT", Vector2(40, 22), Vector2(540, 44), 26, panel).add_theme_color_override("font_color", GOLD_COLOR)
    centered_label("Sign in to keep your collection and Vials tied to your account, or continue as a guest for testing.", Vector2(70, 72), Vector2(480, 58), 15, panel)

    launch_email = LineEdit.new()
    launch_email.position = Vector2(80, 145)
    launch_email.size = Vector2(460, 48)
    launch_email.placeholder_text = "Email address"
    launch_email.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
    launch_email.add_theme_font_size_override("font_size", 17)
    panel.add_child(launch_email)

    launch_password = LineEdit.new()
    launch_password.position = Vector2(80, 205)
    launch_password.size = Vector2(460, 48)
    launch_password.placeholder_text = "Password (6+ characters)"
    launch_password.secret = true
    launch_password.add_theme_font_size_override("font_size", 17)
    panel.add_child(launch_password)

    button("SIGN IN", Vector2(80, 275), Vector2(220, 50), func():
        launch_status.text = "Signing in..."
        NetworkManager.sign_in_with_email(launch_email.text, launch_password.text)
    , panel)
    button("CREATE ACCOUNT", Vector2(320, 275), Vector2(220, 50), func():
        launch_status.text = "Creating account..."
        NetworkManager.create_account_with_email(launch_email.text, launch_password.text)
    , panel)
    button("CONTINUE AS GUEST", Vector2(180, 338), Vector2(260, 46), func():
        launch_status.text = "Starting guest session..."
        NetworkManager.continue_as_guest()
    , panel)

    launch_status = centered_label("", Vector2(55, 388), Vector2(510, 28), 14, panel)

func _on_launch_auth_result(success: bool, message: String) -> void:
    if is_instance_valid(launch_status):
        launch_status.text = message
        launch_status.add_theme_color_override("font_color", Color(0.55, 1.0, 0.70) if success else Color(1.0, 0.55, 0.55))
    if not success:
        return
    if NetworkManager.account_role == "owner":
        message += " Developer access enabled."
    elif NetworkManager.account_role == "tester":
        message += " Tester account ready."
    if is_instance_valid(launch_status):
        launch_status.text = message
    launch_screen_active = false
    await get_tree().create_timer(0.35).timeout
    # Daily rewards are automatic after a successful sign-in/session restore.
    # Players never need to visit a separate daily-reward menu.
    if can_claim_daily_reward():
        auto_claim_daily_reward_after_login()
    elif academy_complete:
        show_home()
    else:
        begin_academy()

func _on_viewport_size_changed() -> void:
    # Keep the account launch screen active during rotation/resizing.
    if launch_screen_active:
        show_launch_screen()
    elif academy_complete:
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
        selected_class = str(cfg.get_value("profile", "class", ""))
        collection_owned = cfg.get_value("collection", "owned", {})
        selected_deck_class = str(cfg.get_value("deck", "class", "Hope"))
        saved_decks = cfg.get_value("decks", "by_class", {})
        if saved_decks.is_empty():
            # Migrate the older single-deck save into its original class slot.
            saved_deck = cfg.get_value("deck", "cards", [])
            if not saved_deck.is_empty():
                saved_decks[selected_deck_class] = saved_deck.duplicate()
        saved_deck = Array(saved_decks.get(selected_deck_class, []))
        academy_complete = bool(cfg.get_value("academy", "complete", false))
        academy_step = int(cfg.get_value("academy", "step", 0))
        academy_reward_claimed = bool(cfg.get_value("academy", "reward_claimed", false))
        daily_reward_day = int(cfg.get_value("daily", "reward_day", 0))
        daily_last_claim_day = int(cfg.get_value("daily", "last_claim_day", -1))
        recovery_challenge_progress = cfg.get_value("challenge", "recovery_progress", {})
        trials_cleared = cfg.get_value("trials", "cleared", {})
        sponsor_leader_unlocked = bool(cfg.get_value("trials", "sponsor_leader_unlocked", false))
        sponsor_sleeve_unlocked = bool(cfg.get_value("trials", "sponsor_sleeve_unlocked", false))
        sponsor_defeated = bool(cfg.get_value("trials", "sponsor_defeated", false))
        selected_leader_skin = str(cfg.get_value("trials", "selected_leader_skin", ""))
        last_seen_whats_new_version = str(cfg.get_value("meta", "last_seen_whats_new_version", ""))
        # Existing players from earlier builds should not lose access.
        if selected_class != "" and not cfg.has_section_key("academy", "complete"):
            academy_complete = true
            academy_reward_claimed = true
        migrate_sponsor_out_of_prebuilt_deck()

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

func save_profile() -> void:
    var cfg := ConfigFile.new()
    cfg.set_value("economy", "gold", gold_balance)
    cfg.set_value("economy", "dust", dust_balance)
    cfg.set_value("economy", "packs", pack_inventory)
    cfg.set_value("packs", "opened", packs_opened)
    cfg.set_value("packs", "platinum_pity", platinum_pity)
    cfg.set_value("profile", "class", selected_class)
    cfg.set_value("collection", "owned", collection_owned)
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
    cfg.set_value("trials", "cleared", trials_cleared)
    cfg.set_value("trials", "sponsor_leader_unlocked", sponsor_leader_unlocked)
    cfg.set_value("trials", "sponsor_sleeve_unlocked", sponsor_sleeve_unlocked)
    cfg.set_value("trials", "sponsor_defeated", sponsor_defeated)
    cfg.set_value("trials", "selected_leader_skin", selected_leader_skin)
    cfg.set_value("meta", "last_seen_whats_new_version", last_seen_whats_new_version)
    cfg.save(SAVE_PATH)

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
    clear_screen()
    add_background(0.58)
    ensure_home_music()

    var active_class := selected_class if selected_class != "" else "Hope"

    # Stable 1280x720 layout. Everything stays inside fixed, non-overlapping regions.
    var top := Panel.new()
    top.position = Vector2(16, 12)
    top.size = Vector2(1248, 64)
    top.add_theme_stylebox_override("panel", style(Color(0.38, 0.30, 0.17), 12))
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
    label("Journey's Dawn  •  " + active_class + " Leader", Vector2(70, 35), Vector2(390, 21), 13, top)
    var wallet := label("GOLD %d     VIALS %d     PACKS %d" % [gold_balance, dust_balance, pack_inventory], Vector2(680, 17), Vector2(450, 30), 16, top)
    wallet.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    button("SUPPORT", Vector2(500, 10), Vector2(120, 44), show_contact_support, top)
    button("SETTINGS", Vector2(1140, 10), Vector2(96, 44), show_test_tools if AccessManager.role_at_least(AccessManager.ROLE_TESTER) else show_launch_screen, top)

    maybe_show_whats_new()

    var nav := Panel.new()
    nav.position = Vector2(16, 88)
    nav.size = Vector2(218, 616)
    nav.add_theme_stylebox_override("panel", style(Color(0.24, 0.20, 0.14), 14))
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
            b.add_theme_stylebox_override("normal", style(GOLD_COLOR, 9))
            b.add_theme_stylebox_override("hover", style(GOLD_COLOR.lightened(0.15), 9))
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
    nav_button.call("HOW TO PLAY", replay_how_to_play, false)
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
    main.add_theme_stylebox_override("panel", style(Color(0.17, 0.24, 0.34), 16))
    root_layer.add_child(main)

    centered_label("CHOOSE YOUR LEADER", Vector2(20, 10), Vector2(976, 34), 22, main).add_theme_color_override("font_color", GOLD_COLOR)
    var order := ["Hope", "Purpose", "Serenity", "Courage"]
    for i in range(order.size()):
        var c: String = order[i]
        var tab := Button.new()
        tab.position = Vector2(24 + i * 241, 50)
        tab.size = Vector2(224, 48)
        tab.text = c.to_upper()
        tab.add_theme_font_size_override("font_size", ui_font_size(15))
        var tab_style := style(class_color(c), 10)
        tab_style.bg_color = Color(0.025, 0.04, 0.075, 0.96)
        tab_style.set_border_width_all(4 if c == active_class else 2)
        tab.add_theme_stylebox_override("normal", tab_style)
        tab.add_theme_stylebox_override("hover", tab_style)
        tab.add_theme_stylebox_override("pressed", tab_style)
        tab.add_theme_color_override("font_color", Color(0.96, 0.97, 1.0))
        tab.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
        tab.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0))
        tab.pressed.connect(func():
            selected_class = c
            selected_deck_class = c
            save_profile()
            show_home()
        )
        main.add_child(tab)

    # Frameless hero showcase. The leader is presented as character art, not as a card.
    var showcase := Panel.new()
    showcase.position = Vector2(24, 114)
    showcase.size = Vector2(548, 430)
    var showcase_style := StyleBoxFlat.new()
    showcase_style.bg_color = Color(0.015, 0.025, 0.05, 0.60)
    showcase_style.border_color = class_color(active_class)
    showcase_style.set_border_width_all(2)
    showcase_style.set_corner_radius_all(18)
    showcase_style.shadow_color = Color(class_color(active_class), 0.28)
    showcase_style.shadow_size = 10
    showcase.add_theme_stylebox_override("panel", showcase_style)
    main.add_child(showcase)

    # Dedicated clipped viewport for the leader art. This prevents the texture from
    # drawing below or outside the showcase on different display scales.
    showcase.clip_contents = true

    var art_frame := Panel.new()
    art_frame.position = Vector2(8, 8)
    art_frame.size = Vector2(532, 344)
    art_frame.clip_contents = true
    var art_frame_style := StyleBoxFlat.new()
    art_frame_style.bg_color = Color(0.008, 0.014, 0.028, 1.0)
    art_frame_style.set_corner_radius_all(14)
    art_frame.add_theme_stylebox_override("panel", art_frame_style)
    showcase.add_child(art_frame)

    var art := TextureRect.new()
    art.texture = current_leader_texture(active_class)
    art.position = Vector2.ZERO
    art.size = art_frame.size
    art.custom_minimum_size = Vector2.ZERO
    art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    # COVERED, not CENTERED: this frame (532x344) is much wider than the
    # square 512x512 source art. CENTERED left large empty bars down both
    # sides; COVERED fills the whole frame with the portrait.
    art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    art.mouse_filter = Control.MOUSE_FILTER_IGNORE
    art.clip_contents = true
    art_frame.add_child(art)

    if sponsor_leader_unlocked:
        var skin_toggle := button(
            "SPONSOR SKIN: ON" if selected_leader_skin == "sponsor" else "SPONSOR SKIN: OFF",
            Vector2(16, 16), Vector2(186, 34), toggle_sponsor_skin, showcase)
        skin_toggle.add_theme_font_size_override("font_size", ui_font_size(11))

    var info_strip := Panel.new()
    info_strip.position = Vector2(8, 356)
    info_strip.size = Vector2(532, 66)
    var info_style := StyleBoxFlat.new()
    info_style.bg_color = Color(0.015, 0.025, 0.05, 0.94)
    info_style.border_color = Color(class_color(active_class), 0.85)
    info_style.set_border_width_all(1)
    info_style.set_corner_radius_all(12)
    info_strip.add_theme_stylebox_override("panel", info_style)
    showcase.add_child(info_strip)

    var leader_name := label(active_class.to_upper(), Vector2(16, 7), Vector2(180, 28), 21, info_strip)
    leader_name.add_theme_color_override("font_color", class_color(active_class))
    var desc := label(class_description(active_class), Vector2(202, 7), Vector2(214, 48), 12, info_strip)
    desc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    var preview_button := button("PREVIEW", Vector2(326, 9), Vector2(94, 46), show_deck_preview, info_strip)
    preview_button.add_theme_font_size_override("font_size", ui_font_size(13))
    var decks_button := button("DECKS", Vector2(426, 9), Vector2(94, 46), show_deck_builder, info_strip)
    decks_button.add_theme_font_size_override("font_size", ui_font_size(15))

    # Right-side actions have their own reserved region and cannot overlap the art.
    var right := Panel.new()
    right.position = Vector2(590, 114)
    right.size = Vector2(402, 430)
    right.add_theme_stylebox_override("panel", style(Color(0.30, 0.24, 0.18), 14))
    main.add_child(right)
    label("RECOVERY CHALLENGE", Vector2(20, 18), Vector2(362, 32), 20, right).add_theme_color_override("font_color", GOLD_COLOR)
    label("Win 3 matches with " + active_class + ".", Vector2(20, 58), Vector2(362, 30), 15, right)
    var challenge_progress := int(recovery_challenge_progress.get(active_class, 0))
    var progress_bg := ColorRect.new(); progress_bg.position = Vector2(20, 98); progress_bg.size = Vector2(362, 12); progress_bg.color = Color(0.05,0.06,0.09); right.add_child(progress_bg)
    var progress := ColorRect.new(); progress.position = Vector2(20, 98); progress.size = Vector2(362.0 * (float(challenge_progress) / 3.0), 12); progress.color = class_color(active_class); right.add_child(progress)
    label("%d / 3" % challenge_progress, Vector2(20, 116), Vector2(362, 24), 13, right).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    label("DAILY REFLECTION", Vector2(20, 160), Vector2(362, 30), 18, right).add_theme_color_override("font_color", GOLD_COLOR)
    var reflection := label("Progress begins with one honest choice. Keep moving forward.", Vector2(20, 198), Vector2(362, 76), 15, right)
    reflection.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    var enter := button("ENTER BATTLE", Vector2(20, 300), Vector2(362, 64), start_battle, right)
    enter.add_theme_font_size_override("font_size", ui_font_size(22))
    enter.add_theme_stylebox_override("normal", style(GOLD_COLOR, 14))
    enter.add_theme_color_override("font_color", Color(0.04, 0.06, 0.10))
    var trials_cta := button("THE TRIALS", Vector2(20, 372), Vector2(362, 50), show_trials, right)
    trials_cta.add_theme_font_size_override("font_size", ui_font_size(18))

    centered_label(BUILD_NAME, Vector2(20, 566), Vector2(976, 28), 12, main).modulate = Color(0.72, 0.78, 0.86)

# ---------------------------------------------------------------------------
# Contact & Support
# ---------------------------------------------------------------------------
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
    var fixes: Array = info.get("fixes", [])
    var upcoming: Array = info.get("upcoming_events", [])
    if fixes.is_empty() and upcoming.is_empty():
        # Nothing authored for this release yet — don't show an empty popup,
        # but still remember it so we don't keep re-checking every frame Home
        # rebuilds this session.
        last_seen_whats_new_version = version
        save_profile()
        return
    show_whats_new_popup(version, fixes, upcoming)

func show_whats_new_popup(version: String, fixes: Array, upcoming: Array) -> void:
    var scrim := ColorRect.new()
    scrim.color = Color(0.02, 0.03, 0.06, 0.85)
    scrim.position = Vector2.ZERO
    scrim.size = Vector2(1280, 720)
    scrim.mouse_filter = Control.MOUSE_FILTER_STOP
    scrim.z_index = 950
    root_layer.add_child(scrim)

    var dialog := Panel.new()
    dialog.position = Vector2(290, 90)
    dialog.size = Vector2(700, 540)
    dialog.z_index = 951
    dialog.add_theme_stylebox_override("panel", style(GOLD_COLOR, 20))
    scrim.add_child(dialog)

    centered_label("WHAT'S NEW", Vector2(30, 20), Vector2(640, 34), 26, dialog).add_theme_color_override("font_color", GOLD_COLOR)
    centered_label("Version %s" % version, Vector2(30, 56), Vector2(640, 22), 14, dialog).modulate = Color(0.75, 0.82, 0.92)

    # The bullet list used to be laid out with a fixed 44px slot per entry
    # and absolute Y coordinates. Any entry whose wrapped text needed more
    # than ~2 lines at 14pt spilled past its slot into the next entry's
    # position, so their text rendered on top of each other -- and a long
    # release note list could also spill past the close button. A
    # ScrollContainer + VBoxContainer lets each label claim exactly the
    # height its own wrapped text needs (no guessed constant) and lets the
    # whole list scroll instead of overflowing the dialog as more entries
    # are added release after release.
    var scroll := ScrollContainer.new()
    scroll.position = Vector2(30, 92)
    scroll.size = Vector2(640, 372)
    dialog.add_child(scroll)
    var list := VBoxContainer.new()
    list.custom_minimum_size = Vector2(624, 0)
    list.add_theme_constant_override("separation", 6)
    scroll.add_child(list)

    if not fixes.is_empty():
        var fixes_header := Label.new()
        fixes_header.text = "BUG FIXES & IMPROVEMENTS"
        fixes_header.add_theme_font_size_override("font_size", ui_font_size(15))
        fixes_header.add_theme_color_override("font_color", Color(0.55, 1.0, 0.70))
        list.add_child(fixes_header)
        for entry in fixes:
            var item := Label.new()
            item.text = "•  %s" % str(entry)
            item.add_theme_font_size_override("font_size", ui_font_size(14))
            item.add_theme_color_override("font_color", Color(0.94,0.95,1.0))
            item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
            item.custom_minimum_size = Vector2(624, 0)
            list.add_child(item)

    if not upcoming.is_empty():
        var spacer := Control.new()
        spacer.custom_minimum_size = Vector2(624, 10)
        list.add_child(spacer)
        var upcoming_header := Label.new()
        upcoming_header.text = "UPCOMING"
        upcoming_header.add_theme_font_size_override("font_size", ui_font_size(15))
        upcoming_header.add_theme_color_override("font_color", Color(1.0, 0.83, 0.35))
        list.add_child(upcoming_header)
        for entry in upcoming:
            var item2 := Label.new()
            item2.text = "•  %s" % str(entry)
            item2.add_theme_font_size_override("font_size", ui_font_size(14))
            item2.add_theme_color_override("font_color", Color(0.94,0.95,1.0))
            item2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
            item2.custom_minimum_size = Vector2(624, 0)
            list.add_child(item2)

    var close_btn := button("GOT IT", Vector2(270, 480), Vector2(160, 48), func():
        last_seen_whats_new_version = version
        save_profile()
        scrim.queue_free()
    , dialog)
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
        if academy_complete:
            show_home()
        else:
            show_first_day_intro()
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
    # Lets a graduated player revisit the core rules lessons. academy_complete
    # is never cleared here, so if they exit mid-replay, gating elsewhere
    # (which only checks academy_complete, not academy_step) is unaffected.
    # Reaching the end just re-shows the graduation screen's "already
    # claimed" branch since academy_complete stays true throughout.
    academy_step = 0
    academy_action_stage = 0
    show_academy_lesson()

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

func show_academy_lesson() -> void:
    clear_screen(); add_background(0.68)
    academy_action_stage = 0
    var lesson_titles := ["PROVING YOURSELF", "THE BATTLEFIELD", "PLAY A FOLLOWER", "COMBAT", "END YOUR TURN", "SPELLS & AMULETS", "LEADER SIGNATURE CARDS", "CARD EFFECTS & KEYWORDS", "RECOVERY & REVIVE", "SPONSOR & SPONSEE", "BUILDING YOUR DECK"]
    var mentors := ["Purpose Champion", "Hope Mentor", "Courage Veteran", "Courage Veteran", "Courage Veteran", "Serenity Guardian", "Recovery Academy Dean", "Purpose Champion", "Hope Mentor", "Purpose Champion", "Recovery Academy Dean"]
    var lesson_class: String = CLASSES[academy_step % CLASSES.size()]
    var accent := class_color(lesson_class)
    header(lesson_titles[academy_step], "Lesson %d of %d • %s" % [academy_step + 1, ACADEMY_LESSON_COUNT, mentors[academy_step]])

    # Mentor portrait chip layered onto the header, so each lesson has a face
    # attached to its voice instead of just a name in small text — the header
    # itself stays untouched since it's shared by every other screen.
    var mentor_chip := Panel.new()
    mentor_chip.position = Vector2(890, 24)
    mentor_chip.size = Vector2(68, 68)
    mentor_chip.add_theme_stylebox_override("panel", style(accent, 34))
    root_layer.add_child(mentor_chip)
    var mentor_class: String = mentors[academy_step].split(" ")[0]
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

    var instruction := centered_label("", Vector2(70, 24), Vector2(950, 78), 21, board)
    instruction.add_theme_color_override("font_color", Color(0.96,0.93,0.82))

    var feedback_chip := Panel.new()
    feedback_chip.position = Vector2(170, 452)
    feedback_chip.size = Vector2(750, 56)
    feedback_chip.add_theme_stylebox_override("panel", style(Color(accent.r, accent.g, accent.b, 0.55), 14))
    board.add_child(feedback_chip)
    academy_feedback = centered_label("Complete the highlighted actions to continue.", Vector2(20, 0), Vector2(710, 56), 18, feedback_chip)

    match academy_step:
        0:
            instruction.text = "Use Second Chance, understand its cost, then spend Momentum yourself."
            build_second_chance_lesson(board)
        1:
            instruction.text = "Learn the battlefield by selecting each important zone."
            build_zone_lesson(board)
        2:
            instruction.text = "Spend Play Points to place a follower onto the battlefield."
            build_play_follower_lesson(board)
        3:
            instruction.text = "Attack an enemy follower, then finish by striking the enemy leader."
            build_combat_lesson(board)
        4:
            instruction.text = "End your turn and see exactly what changes for both players."
            build_end_turn_lesson(board)
        5:
            instruction.text = "Cast a spell for an immediate effect, then play Purpose's real Amulet for ongoing value."
            build_spell_amulet_lesson(board)
        6:
            instruction.text = "Reveal each leader's signature card — the one card that defines their whole strategy."
            build_signature_lesson(board)
        7:
            instruction.text = "Reveal each keyword to learn what it does, using a real card as the example."
            build_keyword_lesson(board)
        8:
            instruction.text = "Move a follower to the Relapse Zone, recover it, then see how overdraw is Revived."
            build_recovery_lesson(board)
        9:
            instruction.text = "Play Sponsor, choose a Sponsee, and trigger the protective bond."
            build_sponsor_lesson(board)
        10:
            instruction.text = "Learn the rules for building a legal deck before you head to the Deck Builder."
            build_deck_building_lesson(board)

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

func lesson_complete() -> void:
    academy_feedback_text("Lesson complete — moving forward.")
    await get_tree().create_timer(0.55).timeout
    academy_step += 1
    academy_action_stage = 0
    save_profile()
    if academy_step >= ACADEMY_LESSON_COUNT:
        show_academy_graduation()
    else:
        show_academy_lesson()

func build_zone_lesson(board: Control) -> void:
    var selected := {"leader":false, "hand":false, "deck":false, "relapse":false, "points":false}
    var counter := [0]
    var make_zone := func(text_value: String, pos: Vector2, key: String):
        var b: Button
        b = button(text_value, pos, Vector2(170, 70), func():
            if selected[key]: return
            selected[key] = true
            counter[0] += 1
            if is_instance_valid(b):
                b.disabled = true
                b.text += "  ✓"
            academy_feedback_text("%s identified. %d of 5 zones found." % [text_value, counter[0]])
            if counter[0] == 5: lesson_complete()
        , board)
    make_zone.call("YOUR LEADER\n20 DEFENSE", Vector2(90, 130), "leader")
    make_zone.call("YOUR HAND\nCards available", Vector2(290, 320), "hand")
    make_zone.call("YOUR DECK\nCards remaining", Vector2(830, 130), "deck")
    make_zone.call("RELAPSE ZONE\nFallen followers", Vector2(830, 320), "relapse")
    make_zone.call("PLAY POINTS\n3 / 3", Vector2(90, 320), "points")

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
        academy_feedback_text("Select a target first.", false)
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
            academy_feedback_text("Defeat the enemy guard before attacking the leader.", false)
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
            academy_feedback_text("Cast Deep Breath first.", false)
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
            academy_feedback_text("Play Daily Progress first.", false)
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
            academy_feedback_text("Move the follower into the Relapse Zone first.", false)
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
            academy_feedback_text("Recover the follower first.", false)
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
            academy_feedback_text("Play The Sponsor first.", false)
            return
        academy_action_stage = 2
        safe_set_text(sponsee, "SPONSEE\n4/4 • BONDED ✓")
        academy_feedback_text("The bond is active. Trigger protection to save the Sponsee from destruction.")
    ,board)
    var protect: Button
    protect = button("ENEMY STRIKE\nDeal lethal damage",Vector2(790,285),Vector2(220,95),func():
        if academy_action_stage != 2:
            academy_feedback_text("Choose the Sponsee first.", false)
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
    label("YOUR REWARD\n\nChoose one legal 40-card starter deck\n500 Gold",Vector2(120,210),Vector2(600,150),27,p).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    if academy_complete:
        label("Training already completed — rewards can only be claimed once.",Vector2(130,390),Vector2(580,45),17,p).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
        button("RETURN HOME",Vector2(270,470),Vector2(300,58),show_home,p)
    else:
        button("CHOOSE YOUR STARTER DECK",Vector2(220,455),Vector2(400,64),show_graduation_class_choice,p)

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


func _show_battle_intro(player_class_name: String, opponent_class_name: String) -> void:
    # Premium versus transition before the battlefield loads.
    var intro := ColorRect.new()
    intro.color = Color(0.005, 0.008, 0.018, 1.0)
    intro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    intro.z_index = 5000
    intro.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(intro)

    var title := Label.new()
    title.text = "WALKING FREE CCG\nJOURNEY'S DAWN"
    title.position = Vector2(390, 44)
    title.size = Vector2(500, 90)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", ui_font_size(28))
    title.add_theme_color_override("font_color", GOLD_COLOR)
    intro.add_child(title)

    var left_art := TextureRect.new()
    left_art.texture = class_leader_texture(player_class_name)
    left_art.position = Vector2(105, 165)
    left_art.size = Vector2(390, 390)
    left_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    left_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    left_art.clip_contents = true
    left_art.modulate = Color(1,1,1,0)
    intro.add_child(left_art)

    var right_art := TextureRect.new()
    right_art.texture = class_leader_texture(opponent_class_name)
    right_art.position = Vector2(785, 165)
    right_art.size = Vector2(390, 390)
    right_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    right_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    right_art.clip_contents = true
    right_art.modulate = Color(1,1,1,0)
    intro.add_child(right_art)

    var left_name := centered_label(player_class_name.to_upper(), Vector2(120, 575), Vector2(360, 44), 25, intro)
    left_name.add_theme_color_override("font_color", class_color(player_class_name).lightened(0.25))
    var right_name := centered_label(opponent_class_name.to_upper(), Vector2(800, 575), Vector2(360, 44), 25, intro)
    right_name.add_theme_color_override("font_color", class_color(opponent_class_name).lightened(0.25))
    var vs := centered_label("VS", Vector2(540, 290), Vector2(200, 100), 64, intro)
    vs.add_theme_color_override("font_color", GOLD_COLOR)
    vs.scale = Vector2(0.35, 0.35)
    vs.pivot_offset = vs.size * 0.5

    var tween := create_tween().set_parallel(true)
    tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(left_art, "position:x", 155.0, 0.45)
    tween.tween_property(left_art, "modulate:a", 1.0, 0.35)
    tween.tween_property(right_art, "position:x", 735.0, 0.45)
    tween.tween_property(right_art, "modulate:a", 1.0, 0.35)
    tween.tween_property(vs, "scale", Vector2.ONE, 0.5)
    await tween.finished
    await get_tree().create_timer(1.15).timeout
    AudioManager.stop_music(0.55)
    var fade := create_tween()
    fade.tween_property(intro, "modulate:a", 0.0, 0.55)
    await fade.finished
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
                    "JD-015":1, "JD-121":3, "JD-001":3, "JD-002":3,
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
    if battle_select_class == "":
        battle_select_class = selected_class if selected_class != "" else "Hope"
    if battle_opponent_class == "":
        battle_opponent_class = "Courage"
    if battle_select_mode != "custom" and not AccessManager.role_at_least(AccessManager.ROLE_OWNER):
        battle_select_mode = "custom"
    battle_opponent_mode = "prebuilt"

    clear_screen()
    add_background(0.78)
    header("BATTLE PREPARATION", "Choose leaders and decks, preview them, then begin battle.")

    var shell := Panel.new()
    shell.position = Vector2(28, 108)
    shell.size = Vector2(1224, 566)
    shell.add_theme_stylebox_override("panel", style(Color(0.20, 0.31, 0.48), 18))
    root_layer.add_child(shell)

    # Class selectors stay above their own side and never overlap portraits.
    centered_label("YOUR LEADER", Vector2(28, 12), Vector2(340, 28), 18, shell).add_theme_color_override("font_color", GOLD_COLOR)
    centered_label("OPPONENT", Vector2(856, 12), Vector2(340, 28), 18, shell).add_theme_color_override("font_color", GOLD_COLOR)
    for i in range(CLASSES.size()):
        var c: String = CLASSES[i]
        var left_b := Button.new()
        left_b.position = Vector2(28 + (i % 2) * 164, 46 + (i / 2) * 44)
        left_b.size = Vector2(154, 38)
        left_b.text = c.to_upper()
        left_b.add_theme_font_size_override("font_size", ui_font_size(12))
        left_b.add_theme_stylebox_override("normal", style(class_color(c).lightened(0.10) if c == battle_select_class else Color(0.08,0.12,0.19), 8))
        left_b.add_theme_color_override("font_color", Color.WHITE)
        left_b.pressed.connect(func(): _battle_selection_set_class(c))
        shell.add_child(left_b)

        var right_b := Button.new()
        right_b.position = Vector2(868 + (i % 2) * 164, 46 + (i / 2) * 44)
        right_b.size = Vector2(154, 38)
        right_b.text = c.to_upper()
        right_b.add_theme_font_size_override("font_size", ui_font_size(12))
        right_b.add_theme_stylebox_override("normal", style(class_color(c).lightened(0.10) if c == battle_opponent_class else Color(0.08,0.12,0.19), 8))
        right_b.add_theme_color_override("font_color", Color.WHITE)
        right_b.pressed.connect(func(): _battle_selection_set_opponent_class(c))
        shell.add_child(right_b)

    _build_battle_leader_panel(battle_select_class, "YOUR LEADER", Vector2(28, 142), shell, false)
    _build_battle_leader_panel(battle_opponent_class, "COMPUTER", Vector2(868, 142), shell, true)

    var center := Panel.new()
    center.position = Vector2(386, 20)
    center.size = Vector2(452, 466)
    center.add_theme_stylebox_override("panel", style(Color(0.30, 0.43, 0.66), 16))
    shell.add_child(center)
    centered_label("VS", Vector2(176, 8), Vector2(100, 44), 30, center).add_theme_color_override("font_color", GOLD_COLOR)

    var your_stats: Dictionary = _battle_preview_stats(battle_select_class, battle_select_mode)
    var opp_stats: Dictionary = _battle_preview_stats(battle_opponent_class, "prebuilt")

    centered_label("YOUR DECK", Vector2(18, 58), Vector2(198, 28), 16, center)
    centered_label("AI DECK", Vector2(236, 58), Vector2(198, 28), 16, center)

    var your_modes: Array = [{"id":"custom", "label":"MY DECK"}]
    if AccessManager.role_at_least(AccessManager.ROLE_OWNER):
        your_modes.append({"id":"meta", "label":"DEV META"})
        your_modes.append({"id":"final_boss", "label":"FINAL BOSS"})
    for i in range(your_modes.size()):
        var option: Dictionary = Dictionary(your_modes[i])
        var mode_id := str(option.get("id", "custom"))
        var b := Button.new()
        b.position = Vector2(18, 92 + i * 45)
        b.size = Vector2(198, 38)
        b.text = str(option.get("label", "DECK"))
        b.add_theme_font_size_override("font_size", ui_font_size(11))
        b.add_theme_stylebox_override("normal", style(GOLD_COLOR if mode_id == battle_select_mode else Color(0.20,0.30,0.48), 8))
        if mode_id == battle_select_mode: b.add_theme_color_override("font_color", Color(0.04,0.06,0.10))
        b.pressed.connect(func(): _battle_selection_set_mode(mode_id))
        center.add_child(b)

    var ai_badge := Button.new()
    ai_badge.position = Vector2(236, 92)
    ai_badge.size = Vector2(198, 38)
    ai_badge.text = "LEGAL PREBUILT"
    ai_badge.disabled = true
    ai_badge.add_theme_stylebox_override("disabled", style(Color(0.18,0.28,0.44), 8))
    center.add_child(ai_badge)

    centered_label("%s • %d CARDS" % [battle_select_class.to_upper(), int(your_stats.get("count",0))], Vector2(18, 236), Vector2(198, 26), 13, center).add_theme_color_override("font_color", class_color(battle_select_class).lightened(0.25))
    centered_label("%s • %d CARDS" % [battle_opponent_class.to_upper(), int(opp_stats.get("count",0))], Vector2(236, 236), Vector2(198, 26), 13, center).add_theme_color_override("font_color", class_color(battle_opponent_class).lightened(0.25))
    centered_label("AVG %.1f  •  F %d  •  S %d" % [float(your_stats.get("average",0.0)), int(your_stats.get("followers",0)), int(your_stats.get("skills",0))], Vector2(14, 268), Vector2(206, 24), 11, center)
    centered_label("AVG %.1f  •  F %d  •  S %d" % [float(opp_stats.get("average",0.0)), int(opp_stats.get("followers",0)), int(opp_stats.get("skills",0))], Vector2(232, 268), Vector2(206, 24), 11, center)
    _draw_curve(center, Array(your_stats.get("curve", [])), Vector2(18, 320), class_color(battle_select_class), 198)
    _draw_curve(center, Array(opp_stats.get("curve", [])), Vector2(236, 320), class_color(battle_opponent_class), 198)
    button("PREVIEW YOUR DECK", Vector2(18, 414), Vector2(198, 38), func(): _show_battle_deck_preview(battle_select_class, battle_select_mode, false), center)
    button("PREVIEW OPPONENT", Vector2(236, 414), Vector2(198, 38), func(): _show_battle_deck_preview(battle_opponent_class, "prebuilt", true), center)

    button("BACK", Vector2(28, 498), Vector2(180, 54), show_home, shell)
    var begin := button("BEGIN BATTLE", Vector2(306, 498), Vector2(500, 54), _battle_selection_start, shell)
    begin.add_theme_font_size_override("font_size", ui_font_size(20))
    begin.add_theme_stylebox_override("normal", style(GOLD_COLOR, 14))
    begin.add_theme_color_override("font_color", Color(0.04,0.06,0.10))
    var practice_begin := button("PRACTICE\n(long timer, no rewards)", Vector2(820, 498), Vector2(376, 54), _battle_selection_start_practice, shell)
    practice_begin.add_theme_font_size_override("font_size", ui_font_size(13))
    practice_begin.add_theme_stylebox_override("normal", style(Color(0.30, 0.55, 0.38), 14))

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
    atlas.region = Rect2(margin, margin, inset_w, inset_h * 0.6)
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
    if not academy_complete:
        begin_academy()
        return
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
            "JD-010":3, "JD-081":3, "JD-082":3, "JD-085":3,
            # Hope payoffs and finishers.
            "JD-007":3, "JD-012":2, "JD-015":1,
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
    var cfg := ConfigFile.new(); cfg.load(SAVE_PATH)
    var stage_id := int(stage["id"])
    var your_class := selected_class if selected_class != "" else "Hope"
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
    var cfg := ConfigFile.new(); cfg.load(SAVE_PATH)
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
    var your_class := selected_class if selected_class != "" else "Hope"
    var cfg := ConfigFile.new(); cfg.load(SAVE_PATH)
    cfg.set_value("trials", "pending_opponent", opponent_class)
    cfg.set_value("trials", "pending_tier", tier)
    cfg.save(SAVE_PATH)
    var battle_cfg := ConfigFile.new()
    battle_cfg.set_value("battle", "mode", "trial")
    battle_cfg.set_value("battle", "your_class", your_class)
    battle_cfg.set_value("battle", "your_deck_mode", "custom")
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
    label("Every pack contains 5 cards • Duplicate protection • Signature Platinum guaranteed by pack 40",Vector2(70,62),Vector2(960,35),17,p).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    button("5 PACKS\n200 GOLD",Vector2(35,120),Vector2(190,92),buy_gold,p)
    button("5 PACKS\n%s" % BillingManager.formatted_price("wf_sober_packs_5", "$2.99"),Vector2(245,120),Vector2(190,92),func(): buy_cash("wf_sober_packs_5"),p)
    button("15 PACKS\n%s" % BillingManager.formatted_price("wf_sober_packs_15", "$7.99"),Vector2(455,120),Vector2(190,92),func(): buy_cash("wf_sober_packs_15"),p)
    button("40 PACKS\n%s" % BillingManager.formatted_price("wf_sober_packs_40", "$19.99"),Vector2(665,120),Vector2(190,92),func(): buy_cash("wf_sober_packs_40"),p)
    button("80 PACKS\n%s" % BillingManager.formatted_price("wf_sober_packs_80", "$39.99"),Vector2(875,120),Vector2(190,92),func(): buy_cash("wf_sober_packs_80"),p)
    button("OPEN OWNED PACKS",Vector2(185,265),Vector2(280,58),show_pack_opening,p)
    button("BUILD A DECK",Vector2(485,265),Vector2(220,58),show_deck_builder,p)
    button("CHECK PURCHASES",Vector2(725,265),Vector2(220,58),BillingManager.restore_pending_purchases,p)
    var billing_text := "Google Play Billing connected" if BillingManager.is_available() else "Cash purchases activate in an installed Google Play test/release build"
    label(billing_text,Vector2(150,345),Vector2(800,34),16,p).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    status_label = label("Next guaranteed Signature Platinum: %d packs" % (40-platinum_pity),Vector2(300,610),Vector2(680,44),20); status_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER

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
    while _pack_sfx_pool.size() < 4:
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
    label("Platinum pity: %d / 40   •   Average pull target: 1 in 11 packs" % platinum_pity,Vector2(310,580),Vector2(660,30),16).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER

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
    var origin_rotation := pack_visual.rotation
    var origin_position := pack_visual.position
    var shake := create_tween()
    shake.tween_property(pack_visual, "rotation", origin_rotation - 0.05, 0.06)
    shake.tween_property(pack_visual, "rotation", origin_rotation + 0.06, 0.07)
    shake.tween_property(pack_visual, "rotation", origin_rotation - 0.05, 0.07)
    shake.tween_property(pack_visual, "rotation", origin_rotation + 0.04, 0.06)
    shake.tween_property(pack_visual, "rotation", origin_rotation, 0.05)
    shake.parallel().tween_property(pack_visual, "position", origin_position + Vector2(0, -6), 0.31).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    await shake.finished

    var flash := ColorRect.new()
    flash.color = Color(1, 1, 1, 0.0)
    flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
    flash.z_index = 500
    root_layer.add_child(flash)
    play_pack_sfx("draw")
    var tear := create_tween().set_parallel(true)
    tear.tween_property(pack_visual, "scale", Vector2(1.15, 1.15), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tear.tween_property(flash, "color:a", 0.85, 0.14)
    await tear.finished
    flash.color.a = 0.85
    var settle := create_tween()
    settle.tween_property(flash, "color:a", 0.0, 0.22)
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
    var guaranteed_platinum := platinum_pity >= 40
    var platinum_hit := guaranteed_platinum or randi_range(1,11) == 1
    var pulled: Array = []
    for i in range(5):
        var rarity := roll_rarity(i == 4, platinum_hit and i == 4)
        var cd := random_card_of_rarity(rarity)
        pulled.append(cd)
        add_card_to_collection(cd)
    if platinum_hit: platinum_pity = 0
    return {"pulled": pulled, "platinum_hit": platinum_hit}

func open_pack() -> void:
    if pack_inventory <= 0: return
    var result := _roll_one_pack()
    save_profile(); show_pack_results(result["pulled"], result["platinum_hit"])

func open_packs_bulk(requested: int) -> void:
    # requested == -1 means "open everything owned". Used by the bulk-open
    # row so players don't have to tap through packs one at a time.
    var count: int = pack_inventory if requested == -1 else min(requested, pack_inventory)
    if count <= 0: return
    var all_pulled: Array = []
    var platinum_count := 0
    for i in range(count):
        var result := _roll_one_pack()
        all_pulled.append_array(result["pulled"])
        if result["platinum_hit"]: platinum_count += 1
    save_profile()
    show_bulk_pack_results(all_pulled, count, platinum_count)

func roll_rarity(guaranteed_silver: bool, force_platinum: bool) -> String:
    if force_platinum: return "Platinum"
    var r := randi_range(1,1000)
    if r <= 25: return "Legendary"
    if r <= 65: return "Epic"
    if r <= 140: return "Gold"
    if guaranteed_silver or r <= 320: return "Silver"
    return "Bronze"

func random_card_of_rarity(rarity: String) -> Dictionary:
    var pool: Array = []
    for cd in cards:
        if str(cd["rarity"]) == rarity: pool.append(cd)
    if pool.is_empty(): pool = cards
    return pool[randi_range(0,pool.size()-1)]

func add_card_to_collection(cd: Dictionary) -> void:
    var id := str(cd["id"]); var rarity := str(cd["rarity"]); var owned := int(collection_owned.get(id,0)); var limit := int(COPY_LIMITS.get(rarity,1))
    if owned >= limit:
        dust_balance += int(DUST_VALUES.get(rarity,10))
    else:
        collection_owned[id] = owned + 1

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
    var scale_by_rarity := {"Bronze": 60.0, "Silver": 75.0, "Gold": 95.0, "Signature Gold": 95.0, "Epic": 115.0, "Legendary": 140.0, "Platinum": 175.0}
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

func show_pack_results(pulled: Array, platinum_hit: bool) -> void:
    clear_screen(); add_background(0.80); header("PACK OPENED", "SIGNATURE PLATINUM!" if platinum_hit else "Cards added to your collection"); currency_bar()
    var backs: Array[Panel] = []
    for i in range(pulled.size()):
        var pos := Vector2(55 + i * 244, 178)
        var back := pack_card_back(pos, Vector2(220, 340))
        root_layer.add_child(back)
        backs.append(back)
    button("OPEN ANOTHER (%d)" % pack_inventory,Vector2(405,550),Vector2(230,55),show_pack_opening)
    button("COLLECTION",Vector2(645,550),Vector2(180,55),show_collection)
    button("DECK BUILDER",Vector2(835,550),Vector2(200,55),show_deck_builder)
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
    var subtitle := "%d packs opened" % pack_count
    if platinum_count > 0:
        subtitle += "  •  %d SIGNATURE PLATINUM!" % platinum_count
    header("PACKS OPENED", subtitle); currency_bar()

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
        wrap.add_child(cp)
        grid.add_child(wrap)

    button("OPEN ANOTHER (%d)" % pack_inventory, Vector2(405, 580), Vector2(230, 55), show_pack_opening)
    button("COLLECTION", Vector2(645, 580), Vector2(180, 55), show_collection)
    button("DECK BUILDER", Vector2(835, 580), Vector2(200, 55), show_deck_builder)

# sfx grows with rarity so a bronze pull stays quick/quiet and a
# legendary/platinum pull actually announces itself.
const PACK_REVEAL_SFX := {"Bronze": "draw", "Silver": "draw", "Gold": "evolve", "Signature Gold": "evolve", "Epic": "evolve_new", "Legendary": "evolve_cinematic", "Platinum": "platinum"}
const PACK_REVEAL_TITLE := {"Epic": "EPIC PULL!", "Legendary": "LEGENDARY PULL!", "Platinum": "SIGNATURE PLATINUM!"}

func _animate_pack_reveal(pulled: Array, backs: Array, platinum_hit: bool) -> void:
    for i in range(pulled.size()):
        await get_tree().create_timer(0.30).timeout
        if i >= backs.size() or not is_instance_valid(backs[i]):
            continue
        var back: Panel = backs[i]
        var pos := back.position
        var size_value := back.size
        var flip_out := create_tween()
        flip_out.tween_property(back, "scale:x", 0.0, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
        await flip_out.finished
        if not is_instance_valid(back):
            continue
        var parent := back.get_parent()
        back.queue_free()
        if not is_instance_valid(parent):
            continue
        var cd: Dictionary = pulled[i]
        var rarity := str(cd.get("rarity", "Bronze"))
        play_pack_sfx(str(PACK_REVEAL_SFX.get(rarity, "draw")))
        pack_rarity_burst(pos + size_value / 2.0, rarity)
        var real := card_panel(cd, pos, size_value)
        real.pivot_offset = size_value / 2.0
        real.scale.x = 0.0
        parent.add_child(real)
        var flip_in := create_tween()
        flip_in.tween_property(real, "scale:x", 1.0, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        if rarity in ["Epic", "Legendary", "Platinum"]:
            await flip_in.finished
            if not is_instance_valid(real):
                continue
            await _spotlight_reveal(real, rarity)

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
    var target_scale: Vector2 = Vector2(1.55, 1.55) if rarity == "Platinum" else (Vector2(1.4, 1.4) if rarity == "Legendary" else Vector2(1.22, 1.22))
    var target_position: Vector2 = screen_center - (real.size * target_scale) / 2.0

    var dimmer := ColorRect.new()
    dimmer.color = Color(0.01, 0.01, 0.03, 0.0)
    dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    dimmer.z_index = 300
    root_layer.add_child(dimmer)

    real.z_index = 320
    var glow_color := card_rarity_color(rarity)
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

    var rise := create_tween().set_parallel(true)
    rise.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    rise.tween_property(dimmer, "color:a", 0.82, 0.22)
    rise.tween_property(real, "position", target_position, 0.32)
    rise.tween_property(real, "scale", target_scale, 0.32)
    rise.tween_property(title, "modulate:a", 1.0, 0.24)
    await rise.finished

    var sparkle_count := 24 if rarity == "Platinum" else (18 if rarity == "Legendary" else 12)
    spawn_reward_sparkles(screen_center, sparkle_count, [glow_color, Color(1, 1, 1)], 100.0)

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
    await settle.finished
    if is_instance_valid(real):
        real.z_index = 0
    dimmer.queue_free()
    title.queue_free()

func _load_menu_art_path(path: String) -> Texture2D:
    if _menu_art_cache.has(path):
        return _menu_art_cache[path] as Texture2D
    # load() resolves Godot-imported JPG/PNG resources in both editor and export.
    var imported: Texture2D = load(path) as Texture2D
    if imported != null:
        _menu_art_cache[path] = imported
        return imported
    # Editor/source fallback for images that have not been imported yet.
    if FileAccess.file_exists(path):
        var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
        var image := Image.new()
        var error: Error = ERR_FILE_UNRECOGNIZED
        if path.to_lower().ends_with(".jpg") or path.to_lower().ends_with(".jpeg"):
            error = image.load_jpg_from_buffer(bytes)
        elif path.to_lower().ends_with(".png"):
            error = image.load_png_from_buffer(bytes)
        if error == OK and not image.is_empty():
            var texture := ImageTexture.create_from_image(image)
            _menu_art_cache[path] = texture
            return texture
    return null

func card_art_texture(cd: Dictionary) -> Texture2D:
    # Use each card's own unique illustration (same lookup as battlefield/hand
    # cards) everywhere in the menus: collection, crafting, deck builder,
    # rewards, and packs. Only fall back to the shared 16-image pool when a
    # card has no catalog ID or no matching art file exists.
    var card_id: String = str(cd.get("id", "")).strip_edges().to_lower()
    if not card_id.is_empty():
        for extension in ["jpg", "png", "jpeg"]:
            var direct_texture: Texture2D = _load_menu_art_path("res://assets/cards/full/%s.%s" % [card_id, extension])
            if direct_texture != null:
                return direct_texture
    var seed_value: int = absi(str(cd.get("id", cd.get("name", "card"))).hash())
    var art_index: int = seed_value % 16
    return _load_menu_art_path("res://assets/cards/art_%02d.png" % art_index)

func card_rarity_color(rarity: String) -> Color:
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

    var frame_style := StyleBoxFlat.new()
    frame_style.bg_color = Color(0.05, 0.045, 0.07, 1.0)
    frame_style.border_color = border
    frame_style.set_border_width_all(3)
    frame_style.set_corner_radius_all(12)
    frame_style.shadow_color = Color(0, 0, 0, 0.55)
    frame_style.shadow_size = 6
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
    art.texture = card_art_texture(cd)
    art.position = Vector2(2, 2)
    art.size = art_frame.size - Vector2(4, 4)
    art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    art.mouse_filter = Control.MOUSE_FILTER_IGNORE
    art_frame.add_child(art)

    # Diagonal glass sheen across the art — a cheap, standard trick that makes
    # a flat photo read as a coated/printed card instead of a pasted image.
    var sheen := GradientTexture2D.new()
    var sheen_gradient := Gradient.new()
    sheen_gradient.colors = PackedColorArray([Color(1,1,1,0.18), Color(1,1,1,0.0)])
    sheen_gradient.offsets = PackedFloat32Array([0.0, 1.0])
    sheen.gradient = sheen_gradient
    sheen.fill_from = Vector2(0.05, 0.0)
    sheen.fill_to = Vector2(0.6, 0.75)
    var sheen_rect := TextureRect.new()
    sheen_rect.texture = sheen
    sheen_rect.position = art.position
    sheen_rect.size = art.size
    sheen_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    art_frame.add_child(sheen_rect)

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
    if is_amulet:
        var amulet_label := label("AMULET", Vector2(9, stats_y), Vector2(size_value.x - 18, 22), 13 if compact_panel else 15, p)
        amulet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        amulet_label.add_theme_color_override("font_color", GOLD_COLOR)
    else:
        var sword := label("⚔", Vector2(pad + 6, stats_y), Vector2(24, 22), 14 if compact_panel else 16, p)
        var stats_text := "%d     %d" % [card_int_value(cd, "attack"), card_int_value(cd, "health")]
        var st := label(stats_text, Vector2(9, stats_y), Vector2(size_value.x - 18, 22), 13 if compact_panel else 16, p)
        st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        var heart := label("♥", Vector2(size_value.x - pad - 30, stats_y), Vector2(24, 22), 14 if compact_panel else 16, p)
        heart.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        heart.add_theme_color_override("font_color", Color(1.0, 0.4, 0.42))

    var rarity_y := stats_y + 22.0
    var r := label(rarity.to_upper(), Vector2(9, rarity_y), Vector2(size_value.x - 18, 18), 9 if compact_panel else 11, p)
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
    var caption := label("%s  •  %s" % [str(cd.get("class", "Neutral")).to_upper(), rarity.to_upper()], Vector2(390, 520), Vector2(500, 30), 16, scrim)
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

func show_collection() -> void:
    # Previously a single unsorted, unfilterable grid of all 121 cards in raw
    # data order -- finding one specific card meant scrolling past every
    # class and rarity mixed together. Class/rarity tabs plus a stable sort
    # (class, then rarity, then cost, then name) turn it into something you
    # can actually navigate, and an owned-count summary up top replaces
    # having to scroll the whole binder just to gauge collection progress.
    clear_screen(); add_background(0.82); header("COLLECTION & CRAFTING","Craft any card from any class • Deck class only matters when building"); currency_bar()
    var guide := label("CREATE: Bronze 50  •  Silver 150  •  Gold 500  •  Epic 900  •  Legendary 2,000  •  Platinum 4,500",Vector2(90,118),Vector2(1100,26),15)
    guide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    guide.add_theme_color_override("font_color", Color(0.78,0.90,1.0))

    var filtered_preview: Array = _collection_filtered_sorted_cards()
    var owned_count := 0
    for cd in filtered_preview:
        if int(collection_owned.get(str(cd["id"]), 0)) > 0:
            owned_count += 1
    var summary := label("Showing %d/%d cards • %d owned in this view" % [filtered_preview.size(), cards.size(), owned_count], Vector2(90,144),Vector2(1100,22),13)
    summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    summary.add_theme_color_override("font_color", Color(0.6,0.66,0.78))

    var class_tabs := ["All"] + CLASSES + ["Neutral"]
    var tab_w: float = 1224.0 / float(class_tabs.size())
    for i in range(class_tabs.size()):
        var c: String = class_tabs[i]
        var tab_btn := button(c.to_upper(), Vector2(28 + i * tab_w, 170), Vector2(tab_w - 6, 34), _collection_set_class_filter.bind(c))
        if c == collection_filter_class:
            tab_btn.add_theme_color_override("font_color", GOLD_COLOR)

    # RARITIES includes tiers ("Signature Platinum") that don't actually
    # exist in data/cards.json yet, so build tabs from what's really on cards
    # (Bronze/Silver/Gold/Epic/Legendary/Platinum) instead of the const --
    # otherwise a tab would show up that always renders "no cards match".
    var rarity_order := ["Bronze", "Silver", "Gold", "Epic", "Legendary", "Platinum", "Signature Gold", "Signature Platinum"]
    var present_rarities: Array = []
    for cd in cards:
        var r := str(cd.get("rarity", "Bronze"))
        if r not in present_rarities:
            present_rarities.append(r)
    present_rarities.sort_custom(func(a, b): return rarity_order.find(a) < rarity_order.find(b))
    var rarity_tabs := ["All"] + present_rarities
    var rtab_w: float = 1224.0 / float(rarity_tabs.size())
    for i in range(rarity_tabs.size()):
        var r: String = rarity_tabs[i]
        var rtab_btn := button(r.to_upper(), Vector2(28 + i * rtab_w, 208), Vector2(rtab_w - 6, 30), _collection_set_rarity_filter.bind(r))
        rtab_btn.add_theme_font_size_override("font_size", 11)
        if r == collection_filter_rarity:
            rtab_btn.add_theme_color_override("font_color", GOLD_COLOR)

    var binder := Panel.new()
    binder.position = Vector2(28,246)
    binder.size = Vector2(1224,430)
    var binder_style := StyleBoxFlat.new()
    binder_style.bg_color = Color(0.01,0.02,0.045,0.78)
    binder_style.border_color = GOLD_COLOR
    binder_style.set_border_width_all(2)
    binder_style.corner_radius_top_left = 14
    binder_style.corner_radius_top_right = 14
    binder_style.corner_radius_bottom_left = 14
    binder_style.corner_radius_bottom_right = 14
    binder.add_theme_stylebox_override("panel",binder_style)
    root_layer.add_child(binder)
    var scroll := ScrollContainer.new()
    scroll.position=Vector2(12,12)
    scroll.size=Vector2(1200,406)
    binder.add_child(scroll)
    if filtered_preview.is_empty():
        centered_label("No cards match this filter.", Vector2(0,180), Vector2(1200,30), 16, scroll)
        return
    var grid := GridContainer.new()
    grid.columns=6
    grid.add_theme_constant_override("h_separation",16)
    grid.add_theme_constant_override("v_separation",18)
    scroll.add_child(grid)
    for cd in filtered_preview:
        var id := str(cd["id"])
        var rarity := str(cd["rarity"])
        var owned := int(collection_owned.get(id,0))
        var limit := int(COPY_LIMITS.get(rarity,1))
        var wrap := VBoxContainer.new()
        wrap.custom_minimum_size=Vector2(180,348)
        var cp := card_panel(cd,Vector2.ZERO,Vector2(174,248))
        wrap.add_child(cp)
        if owned <= 0:
            cp.modulate = Color(0.48,0.52,0.60,0.90)
            var lock_badge := Label.new()
            lock_badge.text = "LOCKED"
            lock_badge.position = Vector2(36,102)
            lock_badge.size = Vector2(102,30)
            lock_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
            lock_badge.add_theme_font_size_override("font_size",12)
            lock_badge.add_theme_color_override("font_color",Color.WHITE)
            lock_badge.add_theme_color_override("font_shadow_color",Color.BLACK)
            lock_badge.add_theme_constant_override("shadow_offset_x",2)
            lock_badge.add_theme_constant_override("shadow_offset_y",2)
            lock_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
            cp.add_child(lock_badge)
        var own := label("Owned %d/%d" % [owned,limit], Vector2.ZERO, Vector2(174,22), 13, wrap)
        own.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        if rarity in ["Bronze", "Silver"]:
            var vial := Button.new()
            vial.text = "VIAL +%d" % int(DUST_VALUES.get(rarity,0))
            vial.disabled = owned <= count_in_deck(id)
            vial.tooltip_text = "Copies currently used in your saved deck are protected."
            vial.pressed.connect(dust_card.bind(id))
            wrap.add_child(vial)
        elif rarity in ["Gold", "Epic", "Legendary"]:
            var auto_note := label("Extras auto-vial", Vector2.ZERO, Vector2(174,18), 11, wrap)
            auto_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
            auto_note.add_theme_color_override("font_color", Color(0.6,0.66,0.78))
        else:
            var protected_note := label("Signature — pack only", Vector2.ZERO, Vector2(174,18), 11, wrap)
            protected_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
            protected_note.add_theme_color_override("font_color", Color(0.6,0.66,0.78))
        if CRAFT_COSTS.has(rarity):
            var craft := Button.new()
            var cost := int(CRAFT_COSTS[rarity])
            craft.text = "CREATE %d" % cost
            craft.disabled = owned >= limit or dust_balance < cost
            craft.pressed.connect(craft_card.bind(id))
            wrap.add_child(craft)
        grid.add_child(wrap)

func _collection_filtered_sorted_cards() -> Array:
    var out: Array = []
    for cd in cards:
        var card_class := str(cd.get("class", "Neutral"))
        if collection_filter_class != "All" and card_class != collection_filter_class:
            continue
        if collection_filter_rarity != "All" and str(cd.get("rarity", "")) != collection_filter_rarity:
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
    clear_screen(); add_background(0.82); header("DECK BUILDER","Separate saved deck for every class • Exactly 40 cards • Class plus Neutral"); currency_bar()
    if selected_class == "":
        label("CHOOSE A CLASS FIRST",Vector2(380,245),Vector2(520,60),34).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
        label("Your class unlocks a starter deck. Pack pulls can then be added here.",Vector2(340,320),Vector2(600,70),19).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
        button("CHOOSE MY CLASS",Vector2(485,420),Vector2(310,60),show_class_choice)
        return
    var class_row := HBoxContainer.new(); class_row.position=Vector2(45,180); class_row.size=Vector2(500,45); root_layer.add_child(class_row)
    for c in CLASSES:
        var b:=Button.new()
        b.text=str(c)
        b.custom_minimum_size=Vector2(115,40)
        b.pressed.connect(switch_deck_class.bind(str(c)))
        class_row.add_child(b)
    var scroll := ScrollContainer.new(); scroll.position=Vector2(45,240); scroll.size=Vector2(780,400); root_layer.add_child(scroll)
    var grid := GridContainer.new(); grid.columns=5; grid.add_theme_constant_override("h_separation",12); grid.add_theme_constant_override("v_separation",12); scroll.add_child(grid)
    for cd in cards:
        if str(cd["class"]) != selected_deck_class and str(cd["class"]) != "Neutral": continue
        var id := str(cd["id"])
        var rarity := str(cd["rarity"])
        var owned := int(collection_owned.get(id, 0))
        var box:=VBoxContainer.new()
        box.custom_minimum_size=Vector2(140,235)
        var cp := card_panel(cd,Vector2.ZERO,Vector2(135,170))
        if owned <= 0:
            cp.modulate = Color(0.48,0.52,0.60,0.90)
        box.add_child(cp)
        if owned > 0:
            var add:=Button.new()
            var allowed := mini(owned,int(COPY_LIMITS.get(rarity,1)))
            add.text="ADD (%d/%d)" % [count_in_deck(id),allowed]
            add.disabled=saved_deck.size()>=40 or count_in_deck(id)>=allowed
            add.pressed.connect(add_card_to_deck.bind(id))
            box.add_child(add)
        elif CRAFT_COSTS.has(rarity):
            var craft := Button.new()
            var cost := int(CRAFT_COSTS[rarity])
            craft.text = "CREATE %d" % cost
            craft.disabled = dust_balance < cost
            craft.pressed.connect(craft_from_deck_builder.bind(id))
            box.add_child(craft)
        else:
            var locked := Label.new()
            locked.text = "PACK ONLY"
            locked.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
            box.add_child(locked)
        grid.add_child(box)
    var side:=Panel.new(); side.position=Vector2(860,180); side.size=Vector2(360,460); side.add_theme_stylebox_override("panel",style(class_color(selected_deck_class),14)); root_layer.add_child(side)
    var deck_leader_frame := Panel.new()
    deck_leader_frame.position = Vector2(92, 10)
    deck_leader_frame.size = Vector2(176, 132)
    deck_leader_frame.clip_contents = true
    deck_leader_frame.add_theme_stylebox_override("panel", style(class_color(selected_deck_class).lightened(0.12), 12))
    side.add_child(deck_leader_frame)
    var deck_leader_art := TextureRect.new()
    deck_leader_art.texture = class_leader_texture(selected_deck_class)
    deck_leader_art.position = Vector2(6, 6)
    deck_leader_art.size = Vector2(164, 120)
    deck_leader_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    deck_leader_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    deck_leader_art.clip_contents = true
    deck_leader_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
    deck_leader_frame.add_child(deck_leader_art)
    label("%s DECK" % selected_deck_class.to_upper(),Vector2(20,146),Vector2(320,28),22,side).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    var validation_label := label("%d / 40 CARDS  •  %s" % [saved_deck.size(),deck_validation_text()],Vector2(16,176),Vector2(328,36),13,side)
    validation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    validation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    validation_label.add_theme_color_override("font_color", GOLD_COLOR if saved_deck.size() == 40 and deck_validation_text().begins_with("DECK VALID") else Color(1.0,0.55,0.5))

    # A scrollable list of exactly what's in this deck right now -- with a
    # per-card remove button -- replaces the old "REMOVE LAST" button, which
    # forced players to remove cards in the reverse order they were added
    # instead of picking the specific card they wanted out.
    var deck_counts: Dictionary = {}
    var deck_order: Array = []
    for id in saved_deck:
        var key := str(id)
        if not deck_counts.has(key):
            deck_order.append(key)
        deck_counts[key] = int(deck_counts.get(key, 0)) + 1
    var list_panel := Panel.new()
    list_panel.position = Vector2(14, 216)
    list_panel.size = Vector2(332, 178)
    list_panel.add_theme_stylebox_override("panel", style(Color(0.03,0.035,0.06,0.85), 8))
    side.add_child(list_panel)
    if deck_order.is_empty():
        centered_label("No cards added yet.", Vector2(0,70), Vector2(332,28), 14, list_panel)
    else:
        var list_scroll := ScrollContainer.new()
        list_scroll.position = Vector2(6,6); list_scroll.size = Vector2(320,166)
        list_panel.add_child(list_scroll)
        var list_box := VBoxContainer.new()
        list_box.custom_minimum_size = Vector2(310,0)
        list_box.add_theme_constant_override("separation", 4)
        list_scroll.add_child(list_box)
        for id in deck_order:
            var cd := card_by_id(id)
            if cd.is_empty(): continue
            var row := HBoxContainer.new()
            row.custom_minimum_size = Vector2(310,26)
            var swatch := ColorRect.new()
            swatch.color = class_color(str(cd.get("class","Neutral")))
            swatch.custom_minimum_size = Vector2(6,22)
            row.add_child(swatch)
            var row_label := Label.new()
            row_label.text = " x%d  %s" % [int(deck_counts[id]), str(cd.get("name","Card"))]
            row_label.custom_minimum_size = Vector2(230,22)
            row_label.add_theme_font_size_override("font_size", 13)
            row_label.clip_text = true
            row.add_child(row_label)
            var remove_btn := Button.new()
            remove_btn.text = "−"
            remove_btn.custom_minimum_size = Vector2(28,24)
            remove_btn.tooltip_text = "Remove one copy"
            remove_btn.pressed.connect(remove_one_from_deck.bind(id))
            row.add_child(remove_btn)
            list_box.add_child(row)
    button("RESET STARTER DECK",Vector2(45,402),Vector2(270,42),func(): build_starter_deck(selected_deck_class); save_profile(); show_deck_builder(),side)

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

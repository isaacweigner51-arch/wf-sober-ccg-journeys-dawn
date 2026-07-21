extends Control

const _LeaderView := preload("res://leader_view.gd")

const STARTING_HEALTH := 20
const BATTLE_BARK_HEALTH_THRESHOLD := 7
const BATTLE_BARK_COOLDOWN := 3.0
const BATTLE_BARK_PLAY_CHANCE := 0.4
const MAX_BOARD := 5

func follower_count(board: Array) -> int:
    var count: int = 0
    for entry in board:
        if entry is Dictionary and not bool(entry.get("is_amulet", false)):
            count += 1
    return count

const MAX_MANA := 10
const MAX_HAND := 9
const TURN_TIME_SECONDS := 75.0
const SLACKING_WARNING_SECONDS := 30.0
const URGENT_WARNING_SECONDS := 10.0
# Practice mode: a much longer per-turn clock so nobody feels rushed while
# reading cards, but still bounded so a match can't sit open forever.
const PRACTICE_TURN_TIME_SECONDS := 180.0

var player_health := STARTING_HEALTH
var enemy_health := STARTING_HEALTH
var player_mana := 0
var player_max_mana := 0
var enemy_mana := 0
var enemy_max_mana := 0
var turn_number := 0
var game_over := false
var busy := false
var selected_attacker := -1
var selected_evolution_cost: int = 0
var attack_drag_line: Line2D = null
var _drag_attack_pending := false  # true only while a drag-initiated attack is resolving
var attack_drag_attacker_idx: int = -1
var player_evolutions_used: Array[bool] = [false, false, false, false]
var enemy_evolutions_used: Array[bool] = [false, false, false, false]

var player_deck: Array = []
var enemy_deck: Array = []
var player_hand: Array = []
var enemy_hand: Array = []
var player_board: Array = []
var enemy_board: Array = []
var player_relapse: Array = []
var enemy_relapse: Array = []
var phoenix_pending_player := false
var phoenix_pending_enemy := false
var phoenix_tier_player := 1
var phoenix_tier_enemy := 1

var player_hand_area: Control
var player_board_area: Control
var enemy_board_area: Control
var player_amulet_area: Control
var enemy_amulet_area: Control
var enemy_hand_area: Control
var player_health_label: Label
var enemy_health_label: Label
var mana_label: Label
var turn_label: Label
var hand_count_label: Label
var evolution_count_label: Label
var status_label: Label
var end_turn_button: Button
var overlay: ColorRect
var game_over_layer: ColorRect
var card_detail_panel: Panel
var player_leader: Button
var enemy_leader: Button
var selected_class := "Serenity"
var enemy_class := "Courage"
var story_mode_battle := false
var story_stage_id := 0
# The Trials: a repeatable PvE gauntlet (menu.gd's show_trials/launch_trial_battle).
# trial_tier is 1-3 for a class leader's escalating gauntlet, or 4 for the
# bonus boss encounter, The Sponsor, whose deck deliberately breaks normal
# deck-building rules (see build_sponsor_trial_deck).
var trial_mode_battle := false
var trial_tier := 0
# Practice: your own saved deck vs. a legal AI deck, generous turn clock,
# no rewards/challenge progress -- purely for trying decks and reading cards.
var practice_mode := false
# Victory/defeat banner+sparkles layer built by _play_victory_sequence(); kept
# as a field (not a local) so show_game_over() can force-free it early if the
# result screen fires while the sequence is still mid-animation.
var finish_layer: Control = null
# _play_victory_sequence's is_instance_valid(finish_layer) checks looked like a
# cutoff, but queue_free() only marks a node for deletion at the END of the
# current frame -- the node stays "valid" for the rest of that frame. If
# show_game_over ran mid-sequence, the coroutine could pass its very next
# is_instance_valid check (still true for one more frame) and add one more
# banner/sparkle/backdrop node to a layer that's about to be destroyed anyway,
# which is exactly the kind of one-frame-late add that reads as the victory
# cinematic (its own "VICTORY" banner) briefly bleeding into/behind the
# result screen's own title and amulet row on a slower device or frame hitch.
# An explicit token invalidates immediately, with no dependency on Godot's
# node-deletion timing.
var victory_sequence_token: int = 0
# Reward lines (e.g. "+75 Gold", "+1 Pack") earned by the win that's about to
# be shown on the result screen. Populated by check_winner() -- which is
# where award_pending_challenge/record_recovery_challenge_win/
# award_pending_trial actually run -- and consumed by _finish_match() when it
# builds the game-over screen further down the coroutine chain.
var pending_match_rewards: Array = []
# Beginner-friendly practice AI: it still plays a legal deck, but it doesn't
# optimize its mana curve, doesn't attack with everything, and evolves less
# often, so new players have real room to experiment without getting run over.
const PRACTICE_MISPLAY_CHANCE := 0.35
const PRACTICE_SKIP_ATTACK_CHANCE := 0.4
const PRACTICE_SKIP_EVOLVE_CHANCE := 0.6
var class_overlay: ColorRect
var evolution_buttons: Array[Button] = []
var evolution_drag_cost: int = 0
var evolution_drag_start := Vector2.ZERO
var evolution_dragging := false
var evolution_drag_orb: Button = null
const EVOLUTION_DRAG_THRESHOLD := 10.0
var pp_pips: Array[ColorRect] = []
var music_player: AudioStreamPlayer
var music_player_alt: AudioStreamPlayer
var music_using_alt := false
var sfx_player: AudioStreamPlayer
var sfx_pool: Array[AudioStreamPlayer] = []
var ambience_player: AudioStreamPlayer
var voice_player: AudioStreamPlayer
var signature_voice_played: Dictionary = {}
# Battle barks: short in-character lines each leader speaks during a live
# match (not story mode) so the table feels like two people in a room
# together, not two silent decks. last_bark_at is a single shared cooldown
# across both leaders so they never talk over each other; the low-health
# flags are one-shot per match so a leader only reacts to falling below the
# threshold once, not on every subsequent hit while already low.
var last_bark_at: float = -999.0
var player_low_health_barked := false
var enemy_low_health_barked := false
var current_music := ""
var turn_time_left: float = TURN_TIME_SECONDS
var player_turn_active := false
var slacking_warning_shown := false
var urgent_warning_shown := false
var turn_timer_bar: ProgressBar
var turn_timer_label: Label
var slacking_popup: Panel
var second_chance_overlay: ColorRect
var second_chance_selected: Array[int] = []
var player_momentum := 0
var enemy_momentum := 0
var momentum_used_this_turn := false
var player_courage_entered := 0
var enemy_courage_entered := 0
var player_progress_counters := 0
var enemy_progress_counters := 0
var player_daily_progress_three_triggered := false
var enemy_daily_progress_three_triggered := false
var player_life_rebuilt := false
var enemy_life_rebuilt := false
var player_purpose_evolves := 0
var enemy_purpose_evolves := 0
var player_pending_temp_pp := 0
var enemy_pending_temp_pp := 0
var player_walking_free_active := false
var enemy_walking_free_active := false
var player_courage_recovery_milestone := false
var enemy_courage_recovery_milestone := false
var player_courage_recovery_evolved := false
var enemy_courage_recovery_evolved := false
var player_hope_recovery_milestone := false
var enemy_hope_recovery_milestone := false
var player_hope_recovery_evolved := false
var enemy_hope_recovery_evolved := false
var player_attacked_this_turn := false
var enemy_attacked_this_turn := false
var player_signature_attack_spoken: Dictionary = {}
var enemy_signature_attack_spoken: Dictionary = {}
var player_goes_first := true
var momentum_button: Button
var momentum_label: Label
var hotseat_mode := false
var active_player_number := 1
var hotseat_second_chance_stage := 0
var hotseat_p1_class := "Hope"
var hotseat_p2_class := "Courage"
var online_mode := false
var online_role := ""
var online_seed := 1
var developer_meta_deck := false
var player_deck_mode := "custom"
var enemy_deck_mode := "custom"
var player_custom_deck_ids: Array = []  # set from battle_setup.cfg when mode=="custom"
var _shake_tween: Tween = null          # screen-shake tween; killed before starting a new one
var online_waiting_for_initial := false
var online_match_started := false
var online_applying_state := false
var online_mulligan_complete := false
var training_mode := false
var training_class := "Hope"
var training_panel: Panel
var training_objective_label: Label
var training_prompt_label: Label
var training_resource_label: Label
var training_objective_index := 0
var training_resource_value := 0
var training_attacked_this_turn := false
var training_played_follower := false
var training_healed := false
var training_recovered := false
var training_played_skill := false
var training_spent_resource := false
var training_destroyed_enemy := false
var training_survived_combat := false
var training_progress_trigger_count := 0
# ── TUTORIAL MODE ─────────────────────────────────────────────────────────────
# Separate from training_mode (class-specific post-tutorial).
# tutorial_lesson  1-6 map to the six battle-based Academy lessons.
# tutorial_step    tracks progress within the current lesson.
var tutorial_mode := false
var tutorial_lesson := 0
var tutorial_step := 0
var _tutorial_complete_called := false
var tutorial_overlay: Panel
var tutorial_instruction_label: Label
var tutorial_heading_label: Label
# ──────────────────────────────────────────────────────────────────────────────
var battle_setup_loaded := false
var battlefield_background: TextureRect

func safe_set_text(node: Object, value: String) -> void:
    if node != null and is_instance_valid(node) and "text" in node:
        node.set("text", value)


func is_mobile_device() -> bool:
    return OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")

func ui_font(value: int) -> int:
    return int(round(float(value) * (1.18 if is_mobile_device() else 1.0)))

func safe_set_disabled(node: Object, value: bool) -> void:
    if node != null and is_instance_valid(node) and "disabled" in node:
        node.set("disabled", value)

# Guards every add_child call that happens after an await, where the parent
# (often `self`, the whole match scene) can have been freed in the meantime
# by the player backing out to the main menu or starting a new match while a
# damage popup / speech bubble / victory-banner coroutine was still mid-flight.
# Without this guard those calls crash with "Cannot call method 'add_child'
# on a previously freed instance"; with it, the leftover cosmetic effect is
# just silently dropped instead. Returns true if the child was actually added.
func safe_add_child(parent: Object, child: Node) -> bool:
    if parent == null or not is_instance_valid(parent) or child == null:
        if child != null and is_instance_valid(child):
            child.queue_free()
        return false
    parent.add_child(child)
    return true

var spell_choice_result: int = -1

func _ready() -> void:
    AudioManager.stop_music(0.35)
    load_battle_setup()
    build_ui()
    setup_audio()
    set_battle_music("battle_early_v2")
    call_deferred("play_class_battle_ambience")
    call_deferred("play_leader_voice")
    if not NetworkManager.game_message.is_connected(_on_online_game_message):
        NetworkManager.game_message.connect(_on_online_game_message)
    if not NetworkManager.disconnected_from_service.is_connected(_on_online_disconnected):
        NetworkManager.disconnected_from_service.connect(_on_online_disconnected)
    if online_mode:
        if online_role == "host":
            start_online_host_match()
        else:
            online_waiting_for_initial = true
            safe_set_text(status_label,"Connected — waiting for the host to deal the match...")
            refresh_ui()
    elif hotseat_mode:
        selected_class = hotseat_p1_class
        enemy_class = hotseat_p2_class
        start_game()
    elif training_mode:
        start_game()
        call_deferred("show_class_training_panel")
    elif tutorial_mode:
        start_game()
        call_deferred("_build_tutorial_overlay")
    else:
        if battle_setup_loaded:
            start_game()
        else:
            show_class_selection()
    set_process(true)

func load_battle_setup() -> void:
    var cfg := ConfigFile.new()
    if cfg.load("user://battle_setup.cfg") == OK:
        battle_setup_loaded = true
        var mode := str(cfg.get_value("battle", "mode", "ai"))
        hotseat_mode = mode == "hotseat"
        online_mode = mode == "online"
        training_mode = mode == "training"
        hotseat_p1_class = str(cfg.get_value("battle", "p1_class", "Hope"))
        hotseat_p2_class = str(cfg.get_value("battle", "p2_class", "Courage"))
        developer_meta_deck = bool(cfg.get_value("battle", "developer_meta", false))
        if online_mode:
            story_mode_battle = false
            trial_mode_battle = false
            practice_mode = false
            online_role = str(cfg.get_value("battle","role","join"))
            selected_class = str(cfg.get_value("battle","your_class","Hope"))
            enemy_class = str(cfg.get_value("battle","opponent_class","Courage"))
            online_seed = int(cfg.get_value("battle","seed",1))
            player_deck_mode = str(cfg.get_value("battle","your_deck_mode","custom"))
            enemy_deck_mode = str(cfg.get_value("battle","opponent_deck_mode","custom"))
        elif mode == "training":
            story_mode_battle = false
            trial_mode_battle = false
            practice_mode = false
            training_class = str(cfg.get_value("training", "class", "Hope"))
            selected_class = training_class
            enemy_class = str(cfg.get_value("battle", "opponent_class", "Courage"))
            player_deck_mode = "prebuilt"
            enemy_deck_mode = "prebuilt"
        elif mode == "tutorial":
            tutorial_mode = true
            tutorial_lesson = int(cfg.get_value("tutorial", "lesson", 1))
            selected_class = str(cfg.get_value("tutorial", "player_class", "Hope"))
            enemy_class = "Courage"
            player_deck_mode = "prebuilt"
            enemy_deck_mode = "prebuilt"
            story_mode_battle = false
            trial_mode_battle = false
            practice_mode = false
        elif mode == "story":
            story_mode_battle = true
            trial_mode_battle = false
            practice_mode = false
            story_stage_id = int(cfg.get_value("battle","story_stage_id",0))
            selected_class = str(cfg.get_value("battle","your_class","Hope"))
            enemy_class = str(cfg.get_value("battle","opponent_class","Courage"))
            player_deck_mode = str(cfg.get_value("battle","your_deck_mode","custom"))
            enemy_deck_mode = str(cfg.get_value("battle","opponent_deck_mode","prebuilt"))
        elif mode == "trial":
            story_mode_battle = false
            trial_mode_battle = true
            practice_mode = false
            trial_tier = int(cfg.get_value("battle","trial_tier",1))
            selected_class = str(cfg.get_value("battle","your_class","Hope"))
            enemy_class = str(cfg.get_value("battle","opponent_class","Courage"))
            player_deck_mode = str(cfg.get_value("battle","your_deck_mode","custom"))
            enemy_deck_mode = str(cfg.get_value("battle","opponent_deck_mode","prebuilt"))
            player_custom_deck_ids = Array(cfg.get_value("battle","player_card_ids",[]))
        elif mode == "practice":
            story_mode_battle = false
            trial_mode_battle = false
            practice_mode = true
            selected_class = str(cfg.get_value("battle","your_class","Hope"))
            enemy_class = str(cfg.get_value("battle","opponent_class","Courage"))
            player_deck_mode = str(cfg.get_value("battle","your_deck_mode","custom"))
            enemy_deck_mode = str(cfg.get_value("battle","opponent_deck_mode","prebuilt"))
        else:
            story_mode_battle = false
            trial_mode_battle = false
            practice_mode = false
            selected_class = str(cfg.get_value("battle","your_class",selected_class))
            enemy_class = str(cfg.get_value("battle","opponent_class",enemy_class))
            player_deck_mode = str(cfg.get_value("battle","your_deck_mode","custom"))
            enemy_deck_mode = str(cfg.get_value("battle","opponent_deck_mode","custom"))
    else:
        battle_setup_loaded = false
        hotseat_mode = false
        online_mode = false

func _process(delta: float) -> void:
    if not player_turn_active or game_over or is_instance_valid(class_overlay) or overlay.visible:
        return
    if busy:
        return
    turn_time_left = maxf(0.0, turn_time_left - delta)
    update_turn_timer_ui()
    if not practice_mode and turn_time_left <= SLACKING_WARNING_SECONDS and not slacking_warning_shown:
        slacking_warning_shown = true
        show_slacking_animation("SITTING ON YOUR STEPS?", "Time to take the next one.", false)
    if not practice_mode and turn_time_left <= URGENT_WARNING_SECONDS and not urgent_warning_shown:
        urgent_warning_shown = true
        show_slacking_animation("DON'T STALL YOUR RECOVERY!", "10 seconds left", true)
    if turn_time_left <= 0.0:
        player_turn_active = false
        safe_set_text(status_label, "Time expired — your turn ended automatically.")
        end_player_turn()

func card(name: String, cost: int, attack: int, health: int, faction: String, rarity: String = "Bronze", ability: String = "", amount: int = 0, display_text: String = "", icon: String = "star", id: String = "") -> Dictionary:
    var is_amulet := ability in ["daily_progress", "life_rebuilt", "sanctuary_serenity", "standing_ground", "second_chances"]
    var is_spell := ability in ["second_chance", "strategic_collapse", "calm_after_storm"]
    var result := {"name": name, "cost": cost, "attack": attack, "health": health, "max_health": health, "faction": faction, "rarity": rarity, "ability": ability, "amount": amount, "display_text": display_text, "icon": icon, "set_name": "Journey's Dawn", "set_code": "JD", "can_attack": false, "is_amulet": is_amulet, "is_spell": is_spell}
    # A handful of battle-only cards (finishers, tokens, and tutorial cards) are
    # not part of the collectible catalog in data/cards.json, so the name-based
    # art hydration in card_view.gd can't find them and they fell back to the
    # recycled 16-image placeholder pool. Giving them an explicit id here lets
    # them resolve their own unique artwork in assets/cards/full/ directly.
    if not id.is_empty():
        result["id"] = id
    return result

func build_class_cards(faction_name: String) -> Array:
    # Journey's Dawn Reforged: each class now has a real curve, engines,
    # interaction, recovery tools, and a class-defining payoff.
    if faction_name == "Serenity":
        return [
            card("Quiet Observer",1,1,2,faction_name,"Bronze","freeze",1,"On Play: Exhaust the strongest enemy next turn.","road"),
            card("Stillwater Acolyte",1,2,3,faction_name,"Bronze","calm_heal",1,"Calm: Restore 1 defense if you ended last turn without attacking.","shield"),
            card("Deep Breath",2,3,2,faction_name,"Bronze","bounce_small",2,"On Play: Return an enemy costing 2 or less to its owner's hand.","hands"),
            card("Patient Listener",2,2,4,faction_name,"Bronze","draw",1,"On Play: Draw a card.","hands"),
            card("Peacekeeper",3,2,5,faction_name,"Bronze","guard",0,"Guard. Enemies must face this follower first.","shield"),
            card("Moment of Peace",3,3,3,faction_name,"Silver","freeze",1,"On Play: Exhaust the strongest enemy next turn.","road"),
            card("Reflective Pool",4,3,5,faction_name,"Silver","bounce",0,"On Play: Return the strongest enemy follower to its owner's hand.","star"),
            card("Tranquil Shieldbearer",4,3,6,faction_name,"Silver","guard",0,"Guard.","shield"),
            card("Sanctuary of Serenity",2,0,0,faction_name,"Gold","sanctuary_serenity",1,"Amulet — stays on the board and has no Attack or Defense. It cannot be attacked or damaged, and can only be removed by effects that specifically target an Amulet. Whenever your leader's Defense is restored, permanently give an allied follower +1/+1.","shield","jd-136"),
            card("Measured Response",5,4,6,faction_name,"Gold","damage_unit",4,"On Play: Deal 4 to the strongest enemy follower.","star"),
            card("Keeper of Balance",5,4,7,faction_name,"Gold","heal_draw",2,"On Play: Restore 2 defense and draw a card.","hands"),
            card("Tide of Acceptance",6,5,7,faction_name,"Gold","damage_all",3,"On Play: Deal 3 to every other follower.","road"),
            card("Voice of Reassurance",3,3,5,faction_name,"Legendary","draw_reduce_two",0,"On Play: Draw 2, then reduce the two highest-cost cards in hand by 1 each.","hands","jd-042"),
            card("Sanctuary Elder",7,5,10,faction_name,"Legendary","guard_heal",4,"Guard. On Play: Restore 4 defense.","shield"),
            card("Moment of Clarity",7,6,8,faction_name,"Legendary","board_clear",0,"On Play: Send every other follower to the Relapse Zone.","star"),
            card("Calm After the Storm",8,0,0,faction_name,"Epic","calm_after_storm",0,"Spell: Destroy all followers. Restore 6 defense. If 5 or more followers were destroyed, draw 2 cards.","star"),
            card("Still Waters",6,4,8,faction_name,"Epic","guard_heal",3,"Guard. On Play: Restore 3 defense.","shield","jd-134"),
            card("Inner Peace",8,6,8,faction_name,"Platinum","serenity_platinum",0,"SIGNATURE PLATINUM — Evolve for free. Restore 5 defense and preserve the first allied follower that would be destroyed each turn.","star"),
            card("Peace Beyond Fear",7,8,12,faction_name,"Legendary","heal_draw_exhaust",5,"On Play: Restore 5 defense, draw a card, and Exhaust all enemy followers next turn.","star","jd-124")]
    if faction_name == "Courage":
        return [
            card("Spark Runner",1,2,1,faction_name,"Bronze","charge",0,"Charge.","flame"),
            card("Defiant Voice",1,1,2,faction_name,"Bronze","damage_enemy",1,"On Play: Deal 1 to the enemy leader.","flame"),
            card("Fearbreaker",2,3,1,faction_name,"Bronze","rush",0,"Rush.","flame"),
            card("Stand Tall",2,2,3,faction_name,"Bronze","self_damage_draw",1,"On Play: Take 1 damage, then draw a card.","hands"),
            card("Forward Vanguard",3,4,2,faction_name,"Bronze","charge",0,"Charge.","road"),
            card("Fight Through It",3,3,3,faction_name,"Silver","buff_all_attack",1,"On Play: Give your other followers +1 Attack this turn.","flame"),
            card("Chainbreaker",4,5,3,faction_name,"Silver","rush",0,"Rush.","flame"),
            card("Never Quit",4,4,4,faction_name,"Silver","survive_buff",1,"After surviving combat, gain +1/+1.","shield"),
            card("Face It Head-On",2,0,0,faction_name,"Gold","standing_ground",1,"Amulet — stays on the board and has no Attack or Defense. It cannot be attacked or damaged, and can only be removed by effects that specifically target an Amulet. Whenever you attack the enemy leader directly, gain Progress. At 3 Progress, allies gain permanent +1 Attack; at 6 transform into Unbreakable Resolve.","flame"),
            card("Face Your Fear",5,5,4,faction_name,"Gold","damage_unit",5,"On Play: Deal 5 to the strongest enemy follower.","flame"),
            card("Rallying Flame",5,4,5,faction_name,"Gold","buff_all",1,"On Play: Give all other allies +1/+1.","flame"),
            card("Heart of the Charge",6,6,5,faction_name,"Gold","charge",0,"Charge.","flame"),
            card("Last Stand",4,3,5,faction_name,"Legendary","low_health_power",0,"On Play: If your leader has 10 or less defense, gain +3/+3 and Charge.","star"),
            card("Controlled Burn",7,6,6,faction_name,"Legendary","damage_all",5,"On Play: Deal 5 to every other follower.","flame"),
            card("Rise Together",7,5,6,faction_name,"Legendary","rise_together",0,"Protector. Arrival: If 3 Courage followers have entered play this match, evolve this for free. When this evolves, give every Courage follower remaining in your deck +1/+1.","star"),
            card("Relentless Drive",6,6,4,faction_name,"Epic","charge_storm",0,"Charge. Storm. Cuts through every follower on the field.","flame","jd-132"),
            card("Battle Hardened",5,5,5,faction_name,"Epic","buff_all",1,"On Play: Give all allied followers +1/+1.","flame","jd-133"),
            card("Rally the Free",8,5,7,faction_name,"Platinum","rally_the_free",0,"SIGNATURE PLATINUM — Evolve for free. Give every Courage follower remaining in your deck +2/+2. The first Courage follower you play each turn gains Rush.","star"),
            card("Phoenix Rising",1,1,1,faction_name,"Legendary","phoenix_rising",0,"Destroyed: returns at the start of your next turn at +1/+1 (1/1 → 10/10). At 10/10, permanently falls. Does not return if banished or transformed.","star","jd-125")]
    if faction_name == "Purpose":
        return [
            card("First Step",1,1,2,faction_name,"Bronze","first_step",0,"Arrival: Draw a card. If you have fewer maximum PP than your opponent, gain 1 temporary PP this turn.","road"),
            card("Daily Reflection",1,0,2,faction_name,"Bronze","daily_reflection",0,"Arrival: Draw a card. If you spent all your PP this turn, gain 1 temporary PP next turn.","hands"),
            card("Purpose Apprentice",2,2,2,faction_name,"Bronze","progress_growth",1,"Progress: Whenever your maximum PP increases, gain +1/+1.","road"),
            card("Milestone Seeker",2,2,3,faction_name,"Bronze","progress_counter",1,"Arrival: Gain 1 Progress. At 3 Progress, draw a card.","star"),
            card("Recovery Journal",3,2,4,faction_name,"Bronze","draw",1,"Arrival: Draw a card.","hands"),
            card("Sponsor's Guidance",2,2,3,faction_name,"Silver","sponsors_guidance",1,"Arrival: If you have gained maximum PP this match, give another ally +1/+1.","hands"),
            card("Small Steps",2,2,2,faction_name,"Silver","small_steps",2,"Arrival: Draw a card. If you spent all your PP this turn, restore 2 defense.","road"),
            card("Steady Architect",4,3,6,faction_name,"Silver","guard",0,"Protector.","shield","jd-126"),
            card("Daily Progress",2,0,0,faction_name,"Gold","daily_progress",1,"Amulet — stays on the board and has no Attack or Defense. It cannot be attacked or damaged, and can only be removed by effects that specifically target an Amulet. End a turn with 0 PP to gain Progress. At 3 Progress gain +1 maximum PP; at 6 transform into A Life Rebuilt.","road"),
            card("Visionary Planner",5,4,6,faction_name,"Gold","draw_reduce",2,"Arrival: Draw 2, then reduce the highest-cost card in hand by 1.","star","jd-127"),
            card("Grand Design",6,5,7,faction_name,"Gold","buff_all",2,"Arrival: Give all other allies +2/+2.","road"),
            card("Structured Plan",4,3,5,faction_name,"Gold","draw_reduce",1,"On Play: Draw a card, then reduce the highest-cost card in hand by 1.","road","jd-137"),
            card("Finding Purpose",4,3,5,faction_name,"Legendary","finding_purpose",1,"Arrival: Gain 1 maximum PP. After 3 Purpose evolutions, gain another maximum PP and draw a card.","star"),
            card("Legacy Mason",6,6,7,faction_name,"Legendary","cost_reduce_all",1,"Arrival: Reduce every card in your hand by 1.","hands","jd-128"),
            card("Worldshaper",7,8,8,faction_name,"Legendary","progress_power",0,"Arrival: Gain +1/+1 for each bonus maximum PP earned this match.","hands"),
            card("Turning Point",3,2,4,faction_name,"Legendary","turning_point",0,"On Play: If your leader has less defense than the enemy, draw 2 cards and gain 1 maximum PP.","road","jd-138"),
            card("Strategic Collapse",8,0,0,faction_name,"Epic","strategic_collapse",0,"Spell — Choose One: Deal 5 damage to all enemy followers, or return all enemy followers with 5 or less Attack to their owner's hand. Draw a card.","star"),
            card("Walking Free",10,6,8,faction_name,"Platinum","walking_free",0,"SIGNATURE PLATINUM — Evolve for free. Give Purpose followers remaining in your deck +1/+1, recover 2 PP, draw 2, and grant a sequencing leader effect.","star"),
            card("Purpose Eternal",9,9,10,faction_name,"Epic","charge_storm",0,"Charge. Storm. Breakthrough — cuts through even a full board.","star","jd-129")]
    return [
        card("Dawnwing Messenger",1,1,2,"Hope","Bronze","draw",1,"On Play: Draw a card.","road"),
        card("Kindled Promise",1,1,3,"Hope","Bronze","heal_leader_draw",1,"Arrival: Restore 1 defense and draw a card.","hands"),
        card("Helping Hand",2,2,3,"Hope","Bronze","heal_buff_comeback",1,"On Play: Restore 1 defense and give another ally +1 Health. If the opponent controls more followers, also draw a card.","hands"),
        card("Open Horizon",2,2,2,"Hope","Bronze","final_draw",1,"Final Breath: Draw a card.","road"),
        card("Beacon Keeper",3,2,4,"Hope","Bronze","renew_growth",1,"Arrival: Restore 1 defense. Renew: Whenever you restore defense, this gains +1/+1.","star"),
        card("Encouraging Words",3,3,4,"Hope","Silver","heal_draw",2,"On Play: Restore 2 defense and draw a card.","star"),
        card("Dreamward Keeper",4,3,6,"Hope","Silver","guard_heal_buff",0,"Guard. Whenever your leader is healed, this follower gains +1/+1.","shield"),
        card("Returned Wanderer",4,4,4,"Hope","Silver","final_draw",2,"Final Breath: Draw 2 cards.","road"),
        card("Promise of Tomorrow",5,4,6,"Hope","Gold","revive_discount",0,"On Play: Recover the most recent allied follower from the Relapse Zone to your hand. It costs 2 less this turn.","star"),
        card("The Comeback Trail",2,0,0,"Hope","Gold","second_chances",1,"Amulet — stays on the board and has no Attack or Defense. It cannot be attacked or damaged, and can only be removed by effects that specifically target an Amulet. Whenever you recover a card from the Relapse Zone, gain Progress. At 3 Progress, restore 3 Defense and permanently buff an ally; at 6 transform into Renewed Hope.","star"),
        card("Light Beyond Night",5,5,5,"Hope","Gold","heal_all",2,"On Play: Restore 2 defense to your leader and all allies.","star"),
        card("Guardian Angel",6,4,8,"Hope","Gold","guard_protect",0,"Guard. The first allied follower destroyed is saved at 1 defense.","shield"),
        card("Renewed Faith",4,3,5,"Hope","Legendary","revive_buff",2,"On Play: Recover a follower; it gains +2/+2.","star"),
        card("Never Forgotten",7,6,9,"Hope","Legendary","revive",0,"On Play: Recover your most recent allied follower.","hands"),
        card("New Beginning",7,5,8,"Hope","Legendary","board_clear_enemy_heal_draw",4,"On Play: Send all enemy followers to their Relapse Zone, restore 4 defense, then draw 2 cards.","star"),
        card("Clean Slate",7,0,0,"Hope","Epic","second_chance",0,"Spell: Transform the 3 enemy followers with the highest Attack into Newcomers (1/1). Restore 3 defense.","hands"),
        card("Healing Grace",5,4,6,"Hope","Epic","heal_draw",4,"On Play: Restore 4 defense and draw a card.","star","jd-135"),
        card("Beacon of Hope",8,5,7,"Hope","Platinum","hope_platinum",0,"SIGNATURE PLATINUM — Evolve for free. Summon two Inspired Volunteers (2/3). Each Volunteer gains +1/+1 whenever your leader is healed.","star"),
        card("Hope Unending",7,5,8,"Hope","Legendary","heal_draw",6,"On Play: Restore 6 defense and draw a card.","star","jd-130")]

func build_universal_cards() -> Array:
    return [
        card("Newcomer",1,1,2,"Universal","Bronze","sponsor_ready",0,"If you control a Sponsor, gain Guard.","road"),
        card("One Day at a Time",1,1,1,"Universal","Bronze","revive_to_hand",0,"On Play: Return a low-cost follower from your Relapse Zone to your hand.","hands"),
        card("Recovery Journal",2,1,3,"Universal","Bronze","draw",1,"On Play: Draw a card.","hands"),
        card("Home Group",2,2,3,"Universal","Silver","heal_draw",1,"On Play: Restore 1 defense and draw a card.","flame"),
        card("Step Study",3,2,4,"Universal","Silver","draw_reduce",1,"On Play: Draw, then reduce the highest-cost card in hand by 1.","road"),
        card("Back on Track",3,3,3,"Universal","Silver","revive_to_hand",0,"On Play: Return a follower from your Relapse Zone to your hand.","road"),
        card("Service Work",4,3,5,"Universal","Gold","buff_all",1,"On Play: Give all other allies +1/+1.","hands"),
        card("Recovery Meeting",4,3,6,"Universal","Gold","heal_draw",2,"On Play: Restore 2 defense and draw a card.","hands"),
        card("Fresh Perspective",5,4,6,"Universal","Gold","bounce",0,"On Play: Return the strongest enemy follower to its owner's hand.","star"),
        card("Renewed Resolve",6,5,6,"Universal","Legendary","revive_buff",2,"On Play: Recover a follower; it gains +2/+2.","star"),
        card("Rock Bottom",7,4,7,"Universal","Legendary","board_clear_draw",0,"On Play: Send every other follower to the Relapse Zone. Both players draw 2.","flame"),
        card("The Sponsor",8,5,9,"Universal","Platinum","sponsor",0,"SIGNATURE PLATINUM — Arrival: Summon 2 Sponsees. End of your turn: Summon another Sponsee. Sponsees are 3/3 and carry your class path's strength.","star")]

func build_class_deck(faction_name: String) -> Array:
    var class_cards: Array = build_class_cards(faction_name)
    var universal_cards: Array = []
    # The Sponsor is a neutral chase card and build-around, not an automatic
    # inclusion in any prebuilt class deck. Players add it in Deck Builder.
    for neutral_card in build_universal_cards():
        if str(neutral_card.get("ability", "")) != "sponsor":
            universal_cards.append(neutral_card)
    var deck: Array = []
    deck.append_array(class_cards.duplicate(true))
    deck.append_array(universal_cards.duplicate(true))
    # Pad with extra copies of the class's own cards (starting with a smooth
    # low-cost curve) until the deck reaches exactly 40 cards. Computed from
    # the actual pool size rather than hardcoded so adding or removing class
    # cards can never leave the deck over- or under-sized.
    const TARGET_DECK_SIZE := 40
    var pad_index := 0
    while deck.size() < TARGET_DECK_SIZE and not class_cards.is_empty():
        deck.append(class_cards[pad_index % class_cards.size()].duplicate(true))
        pad_index += 1
    return deck

func build_story_opponent_deck(faction_name: String, stage_id: int) -> Array:
    # Every AI class deck elsewhere in the game is built by build_class_deck,
    # which is fully deterministic -- the same 40 cards, in the same counts,
    # every single time. That's fine for a generic "prebuilt" practice match,
    # but it means every Story Mode opponent of a given class (even distinct
    # named characters across different stages) fielded the exact same list,
    # which read as "it's a set deck they use" instead of a cast of distinct
    # opponents. Seeding a shuffle on the stage id keeps each stage's
    # opponent legal (same rarity copy limits) while giving it its own card
    # mix, so stages don't feel interchangeable even when they share a class.
    var pool: Array = build_class_cards(faction_name)
    for neutral_card in build_universal_cards():
        if str(neutral_card.get("ability", "")) != "sponsor":
            pool.append(neutral_card)
    var rng := RandomNumberGenerator.new()
    rng.seed = hash("story_deck_%s_%d" % [faction_name, stage_id])
    var shuffled: Array = pool.duplicate(true)
    for i in range(shuffled.size() - 1, 0, -1):
        var j := rng.randi_range(0, i)
        var tmp = shuffled[i]
        shuffled[i] = shuffled[j]
        shuffled[j] = tmp
    var deck: Array = []
    var counts := {}
    var idx := 0
    var guard := 0
    while deck.size() < 40 and guard < shuffled.size() * 8:
        var c: Dictionary = shuffled[idx % shuffled.size()]
        var card_name := str(c.get("name", "Card"))
        var rarity := str(c.get("rarity", "Bronze"))
        var limit := 2 if rarity in ["Platinum", "Signature Platinum", "Signature Gold"] else 3
        if int(counts.get(card_name, 0)) < limit:
            deck.append(c.duplicate(true))
            counts[card_name] = int(counts.get(card_name, 0)) + 1
        idx += 1
        guard += 1
    return deck

func build_trial_deck(faction_name: String, tier: int) -> Array:
    # The Trials: three escalating, fully legal gauntlet decks per leader.
    # Trial 3 is that leader's actual curated best deck (build_class_deck) --
    # deliberately unchanged so it stays "the hardest legal deck you can
    # face." Trials 1-2 draw from the same real card pool but are banded by
    # rarity so they read as genuinely weaker, legal decks rather than
    # reskins of the same 40 cards.
    if tier >= 3:
        return build_class_deck(faction_name)
    var pool: Array = build_class_cards(faction_name)
    for neutral_card in build_universal_cards():
        if str(neutral_card.get("ability", "")) != "sponsor":
            pool.append(neutral_card)
    var rarity_rank := {"Bronze": 0, "Silver": 1, "Gold": 2, "Epic": 3, "Legendary": 4, "Platinum": 5}
    var max_rank := 2 if tier <= 1 else 4
    var banded: Array = []
    for card_data in pool:
        if int(rarity_rank.get(str(card_data.get("rarity", "Bronze")), 0)) <= max_rank:
            banded.append(card_data)
    if banded.is_empty():
        banded = pool.duplicate(true)
    var rng := RandomNumberGenerator.new()
    rng.seed = hash("trial_deck_%s_%d" % [faction_name, tier])
    var shuffled: Array = banded.duplicate(true)
    for i in range(shuffled.size() - 1, 0, -1):
        var j := rng.randi_range(0, i)
        var tmp = shuffled[i]
        shuffled[i] = shuffled[j]
        shuffled[j] = tmp
    var deck: Array = []
    var counts := {}
    _fill_legal_deck(deck, counts, shuffled)
    if deck.size() < 40:
        _fill_legal_deck(deck, counts, pool)
    return deck

func _fill_legal_deck(deck: Array, counts: Dictionary, source: Array) -> void:
    if source.is_empty():
        return
    var idx := 0
    var guard := 0
    while deck.size() < 40 and guard < source.size() * 10:
        var card_data: Dictionary = source[idx % source.size()]
        var card_name := str(card_data.get("name", "Card"))
        var rarity := str(card_data.get("rarity", "Bronze"))
        var limit := 2 if rarity in ["Platinum", "Signature Platinum", "Signature Gold"] else 3
        if int(counts.get(card_name, 0)) < limit:
            deck.append(card_data.duplicate(true))
            counts[card_name] = int(counts.get(card_name, 0)) + 1
        idx += 1
        guard += 1

func build_sponsor_trial_deck() -> Array:
    # The Sponsor: the bonus boss beyond the three Trials. His deck is the
    # one deliberately illegal exception in the game -- it mixes the best
    # cards from every class (no player deck can do this) and runs 3 copies
    # of The Sponsor himself (normally capped at 1). Every other card still
    # respects its own normal copy limit, so the deck reads as "the best of
    # everything," not one card copy-pasted.
    var sponsor_card := {}
    for neutral_card in build_universal_cards():
        if str(neutral_card.get("ability", "")) == "sponsor":
            sponsor_card = neutral_card
            break
    var deck: Array = []
    var counts := {}
    if not sponsor_card.is_empty():
        for i in range(3):
            deck.append(sponsor_card.duplicate(true))
        counts[str(sponsor_card.get("name", "The Sponsor"))] = 3
    var rarity_rank := {"Bronze": 0, "Silver": 1, "Gold": 2, "Epic": 3, "Legendary": 4, "Platinum": 5}
    var pool: Array = []
    for faction_name in ["Hope", "Courage", "Serenity", "Purpose"]:
        pool.append_array(build_class_cards(faction_name))
    for neutral_card in build_universal_cards():
        if str(neutral_card.get("ability", "")) != "sponsor":
            pool.append(neutral_card)
    pool.sort_custom(func(a, b):
        return int(rarity_rank.get(str(a.get("rarity", "Bronze")), 0)) > int(rarity_rank.get(str(b.get("rarity", "Bronze")), 0))
    )
    _fill_legal_deck(deck, counts, pool)
    return deck

func build_deck_for_mode(faction_name: String, deck_mode: String) -> Array:
    if story_mode_battle and deck_mode == "prebuilt" and faction_name == enemy_class:
        return build_story_opponent_deck(faction_name, story_stage_id)
    if trial_mode_battle and faction_name == enemy_class:
        if trial_tier >= 4:
            return build_sponsor_trial_deck()
        return build_trial_deck(faction_name, trial_tier)
    match deck_mode:
        "meta":
            return build_developer_meta_deck(faction_name)
        "final_boss":
            return build_developer_final_boss_deck()
        "custom":
            if not player_custom_deck_ids.is_empty():
                var custom := _build_deck_from_id_list(player_custom_deck_ids)
                if not custom.is_empty():
                    return custom
            return build_class_deck(faction_name)
        _:
            return build_class_deck(faction_name)

## Build a full card-dict Array from a list of card IDs (as stored in deck slots).
## Unknown IDs are skipped with a warning; the deck may be shorter than 40 as a result.
func _build_deck_from_id_list(ids: Array) -> Array:
    var result: Array = []
    for raw_id in ids:
        var id := str(raw_id)
        var found := false
        for pool_fn in [build_class_cards.bind("Hope"), build_class_cards.bind("Courage"),
                        build_class_cards.bind("Serenity"), build_class_cards.bind("Purpose"),
                        build_universal_cards]:
            var pool: Array = pool_fn.call()
            for cd in pool:
                if str(cd.get("id","")) == id or str(cd.get("name","")) == id:
                    result.append(cd.duplicate(true))
                    found = true
                    break
            if found:
                break
        if not found:
            push_warning("_build_deck_from_id_list: unknown id %s — skipped" % id)
    return result

func _developer_curve_deck(pool: Array, low_target: int = 14, mid_target: int = 14, high_target: int = 12) -> Array:
    var buckets := {"low": [], "mid": [], "high": []}
    var rarity_score := {"Platinum":100,"Legendary":82,"Epic":66,"Gold":50,"Silver":30,"Bronze":16}
    for card_data in pool:
        var c: Dictionary = card_data.duplicate(true)
        var cost := int(c.get("cost", 0))
        var bucket := "low" if cost <= 3 else ("mid" if cost <= 6 else "high")
        buckets[bucket].append(c)
    for key in buckets.keys():
        buckets[key].sort_custom(func(a: Dictionary, b: Dictionary):
            var sa := int(rarity_score.get(str(a.get("rarity", "Bronze")), 16)) + int(a.get("attack", 0)) + int(a.get("health", 0))
            var sb := int(rarity_score.get(str(b.get("rarity", "Bronze")), 16)) + int(b.get("attack", 0)) + int(b.get("health", 0))
            return sa > sb
        )
    var result: Array = []
    var counts := {}
    var targets := {"low": low_target, "mid": mid_target, "high": high_target}
    for key in ["low", "mid", "high"]:
        var added := 0
        var pass_index := 0
        while added < int(targets[key]) and not buckets[key].is_empty():
            var card_data: Dictionary = buckets[key][pass_index % buckets[key].size()]
            var name := str(card_data.get("name", "Card"))
            var rarity := str(card_data.get("rarity", "Bronze"))
            var limit := 2 if rarity in ["Platinum", "Signature Platinum", "Signature Gold"] else 3
            if int(counts.get(name, 0)) < limit:
                result.append(card_data.duplicate(true))
                counts[name] = int(counts.get(name, 0)) + 1
                added += 1
            pass_index += 1
            if pass_index > buckets[key].size() * 5:
                break
    var fallback_pool: Array = buckets["low"] + buckets["mid"] + buckets["high"]
    var fallback_index := 0
    while result.size() < 40 and not fallback_pool.is_empty():
        var c: Dictionary = fallback_pool[fallback_index % fallback_pool.size()]
        var n := str(c.get("name", "Card"))
        var r := str(c.get("rarity", "Bronze"))
        var lim := 1 if r == "Platinum" else (2 if r == "Legendary" else 3)
        if int(counts.get(n, 0)) < lim:
            result.append(c.duplicate(true))
            counts[n] = int(counts.get(n, 0)) + 1
        fallback_index += 1
        if fallback_index > fallback_pool.size() * 8:
            break
    return result

func _find_card_by_name(pool: Array, card_name: String) -> Dictionary:
    for card_data in pool:
        if str(card_data.get("name", "")) == card_name:
            return Dictionary(card_data).duplicate(true)
    return {}

func _append_named_cards(deck: Array, pool: Array, names: Array) -> void:
    for name_value in names:
        var found := _find_card_by_name(pool, str(name_value))
        if not found.is_empty() and deck.size() < 40:
            deck.append(found)

func build_developer_final_boss_deck() -> Array:
    # Owner-only balance benchmark: one cohesive Purpose/Sponsor engine.
    # It is powerful through synergy and curve quality, not illegal advantages.
    var pool: Array = build_class_cards("Purpose")
    pool.append_array(build_universal_cards())
    var deck: Array = []
    _append_named_cards(deck, pool, [
        "The Sponsor", "Walking Free",
        "Newcomer", "Newcomer", "Newcomer",
        "Sponsor's Guidance", "Sponsor's Guidance", "Sponsor's Guidance",
        "Daily Progress", "Daily Progress", "Daily Progress",
        "Sponsor's Lesson", "Sponsor's Lesson",
        "Accountability Call", "Accountability Call", "Accountability Call",
        "Sponsorship Chain", "Sponsorship Chain",
        "Service Keeps Us Sober", "Service Keeps Us Sober",
        "Never Alone", "Never Alone"
    ])
    var tuned := _developer_curve_deck(pool, 16, 14, 10)
    for card_data in tuned:
        if deck.size() >= 40:
            break
        var name := str(card_data.get("name", ""))
        var rarity := str(card_data.get("rarity", "Bronze"))
        var limit := 2 if rarity in ["Platinum", "Signature Platinum", "Signature Gold"] else 3
        var copies := 0
        for existing in deck:
            if str(existing.get("name", "")) == name:
                copies += 1
        if copies < limit:
            deck.append(Dictionary(card_data).duplicate(true))
    return deck

func build_developer_meta_deck(faction_name: String) -> Array:
    # Owner-only meta gauntlet. Each class receives its own strongest legal,
    # cohesive archetype deck rather than a generic rarity pile.
    var pool: Array = build_class_cards(faction_name)
    pool.append_array(build_universal_cards())
    var deck: Array = []

    match faction_name:
        "Courage":
            _append_named_cards(deck, pool, [
                "Rally the Free",
                "Spark Runner", "Spark Runner", "Spark Runner",
                "Defiant Voice", "Defiant Voice", "Defiant Voice",
                "Fearbreaker", "Fearbreaker", "Fearbreaker",
                "Forward Vanguard", "Forward Vanguard", "Forward Vanguard",
                "Fight Through It", "Fight Through It", "Fight Through It",
                "Chainbreaker", "Chainbreaker", "Chainbreaker",
                "Rallying Flame", "Rallying Flame", "Rallying Flame",
                "Heart of the Charge", "Heart of the Charge",
                "Rise Together", "Rise Together",
                "Stand Tall", "Stand Tall", "Stand Tall",
                "Face It Head-On", "Face It Head-On", "Face It Head-On",
                "Never Quit", "Never Quit", "Never Quit"
            ])
        "Hope":
            _append_named_cards(deck, pool, [
                "Beacon of Hope", "Renewed Faith",
                "Dawnwing Messenger", "Dawnwing Messenger", "Dawnwing Messenger",
                "Kindled Promise", "Kindled Promise", "Kindled Promise",
                "Helping Hand", "Helping Hand", "Helping Hand",
                "Beacon Keeper", "Beacon Keeper", "Beacon Keeper",
                "Encouraging Words", "Encouraging Words", "Encouraging Words",
                "Dreamward Keeper", "Dreamward Keeper", "Dreamward Keeper",
                "Promise of Tomorrow", "Promise of Tomorrow", "Promise of Tomorrow",
                "Guardian Angel", "Guardian Angel",
                "Never Forgotten", "Never Forgotten",
                "Open Horizon", "Open Horizon", "Open Horizon",
                "Returned Wanderer", "Returned Wanderer", "Returned Wanderer",
                "The Comeback Trail", "The Comeback Trail", "The Comeback Trail"
            ])
        "Serenity":
            _append_named_cards(deck, pool, [
                "Inner Peace", "Calm After the Storm",
                "Quiet Observer", "Quiet Observer", "Quiet Observer",
                "Stillwater Acolyte", "Stillwater Acolyte", "Stillwater Acolyte",
                "Deep Breath", "Deep Breath", "Deep Breath",
                "Patient Listener", "Patient Listener", "Patient Listener",
                "Peacekeeper", "Peacekeeper", "Peacekeeper",
                "Moment of Peace", "Moment of Peace", "Moment of Peace",
                "Tranquil Shieldbearer", "Tranquil Shieldbearer", "Tranquil Shieldbearer",
                "Measured Response", "Measured Response", "Measured Response",
                "Keeper of Balance", "Keeper of Balance", "Keeper of Balance",
                "Voice of Reassurance", "Voice of Reassurance",
                "Sanctuary Elder", "Sanctuary Elder",
                "Sanctuary of Serenity", "Sanctuary of Serenity", "Sanctuary of Serenity"
            ])
        "Purpose":
            _append_named_cards(deck, pool, [
                "Walking Free", "The Sponsor", "Strategic Collapse",
                "Newcomer", "Newcomer", "Newcomer",
                "First Step", "First Step", "First Step",
                "Daily Reflection", "Daily Reflection", "Daily Reflection",
                "Purpose Apprentice", "Purpose Apprentice", "Purpose Apprentice",
                "Sponsor's Guidance", "Sponsor's Guidance", "Sponsor's Guidance",
                "Daily Progress", "Daily Progress", "Daily Progress",
                "Sponsor's Lesson", "Sponsor's Lesson", "Sponsor's Lesson",
                "Accountability Call", "Accountability Call", "Accountability Call",
                "Sponsorship Chain", "Sponsorship Chain", "Sponsorship Chain",
                "Service Keeps Us Sober", "Service Keeps Us Sober"
            ])
        _:
            pass

    # Fill any remaining slots with the strongest legal cards on a healthy curve.
    var tuned := _developer_curve_deck(pool, 17, 14, 9)
    for card_data in tuned:
        if deck.size() >= 40:
            break
        var name := str(card_data.get("name", ""))
        var rarity := str(card_data.get("rarity", "Bronze"))
        var limit := 2 if rarity in ["Platinum", "Signature Platinum", "Signature Gold"] else 3
        var copies := 0
        for existing in deck:
            if str(existing.get("name", "")) == name:
                copies += 1
        if copies < limit:
            deck.append(Dictionary(card_data).duplicate(true))
    return deck


func prepare_balanced_draw_order(source_deck: Array) -> Array:
    # v0.2.8: Curve-smoothing prevents repeated opening bricks while preserving
    # randomness within low-, mid-, and high-cost groups. The same rule applies
    # to both players and the AI. draw_card() draws from the end of the Array.
    var low: Array = []
    var mid: Array = []
    var high: Array = []
    for card_data in source_deck:
        var cost := int(card_data.get("cost", 0))
        if cost <= 3:
            low.append(card_data.duplicate(true))
        elif cost <= 6:
            mid.append(card_data.duplicate(true))
        else:
            high.append(card_data.duplicate(true))
    low.shuffle()
    mid.shuffle()
    high.shuffle()
    var early: Array = []
    for i in range(mini(4, low.size())):
        early.append(low.pop_back())
    for i in range(mini(3, mid.size())):
        early.append(mid.pop_back())
    for i in range(mini(1, high.size())):
        early.append(high.pop_back())
    var leftovers: Array = []
    leftovers.append_array(low)
    leftovers.append_array(mid)
    leftovers.append_array(high)
    leftovers.shuffle()
    while early.size() < mini(8, source_deck.size()) and not leftovers.is_empty():
        early.append(leftovers.pop_back())
    early.shuffle()
    leftovers.shuffle()
    leftovers.append_array(early)
    return leftovers

func show_class_selection() -> void:
    if is_instance_valid(class_overlay):
        class_overlay.queue_free()

    class_overlay = ColorRect.new()
    class_overlay.color = Color(0.008, 0.014, 0.03, 1.0)
    class_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    class_overlay.z_index = 2000
    add_child(class_overlay)

    var backdrop := TextureRect.new()
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    backdrop.texture = load("res://assets/ui/home_bg.png") as Texture2D
    backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    backdrop.modulate = Color(0.42, 0.52, 0.68, 0.42)
    backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
    class_overlay.add_child(backdrop)

    var shade := ColorRect.new()
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.color = Color(0.006, 0.012, 0.028, 0.72)
    shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    class_overlay.add_child(shade)

    var header := Panel.new()
    header.position = Vector2(44, 26)
    header.size = Vector2(1192, 104)
    var header_style := StyleBoxFlat.new()
    header_style.bg_color = Color(0.018, 0.033, 0.065, 0.96)
    header_style.border_color = Color(0.95, 0.76, 0.28, 0.9)
    header_style.set_border_width_all(2)
    header_style.set_corner_radius_all(16)
    header_style.shadow_color = Color(0,0,0,0.65)
    header_style.shadow_size = 10
    header.add_theme_stylebox_override("panel", header_style)
    class_overlay.add_child(header)

    var title := Label.new()
    title.text = "CHOOSE YOUR PATH"
    title.position = Vector2(28, 12)
    title.size = Vector2(760, 44)
    title.add_theme_font_size_override("font_size", ui_font(34))
    title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.42))
    header.add_child(title)

    var subtitle := Label.new()
    subtitle.text = "Choose a class and receive a complete 40-card starter deck"
    subtitle.position = Vector2(30, 58)
    subtitle.size = Vector2(780, 28)
    subtitle.add_theme_font_size_override("font_size", ui_font(16))
    subtitle.add_theme_color_override("font_color", Color(0.82, 0.90, 1.0))
    header.add_child(subtitle)

    var home := Button.new()
    home.text = "HOME"
    home.position = Vector2(1010, 25)
    home.size = Vector2(150, 54)
    home.focus_mode = Control.FOCUS_NONE
    header.add_child(home)
    home.pressed.connect(func(): class_overlay.queue_free())

    var classes := ["Hope", "Courage", "Serenity", "Purpose"]
    var descriptions := [
        "Healing • Recovery • Card Draw",
        "Fast Attacks • Rush • Pressure",
        "Defense • Control • Protection",
        "Growth • Planning • Finishers"
    ]
    var platinum_names := ["Beacon of Hope", "Rally the Free", "Inner Peace", "Walking Free"]

    for i in range(4):
        var button := make_class_choice(classes[i], descriptions[i], platinum_names[i])
        button.position = Vector2(48 + i * 298, 154)
        class_overlay.add_child(button)
        var chosen_class: String = classes[i]
        button.pressed.connect(func(): choose_class(chosen_class))

    var footer := Label.new()
    footer.text = "Each deck uses one class plus Neutral cards • 40 cards total • Copy limits enforced"
    footer.position = Vector2(110, 660)
    footer.size = Vector2(1060, 34)
    footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    footer.add_theme_font_size_override("font_size", ui_font(15))
    footer.add_theme_color_override("font_color", Color(0.78, 0.86, 0.98))
    class_overlay.add_child(footer)

func make_class_choice(class_name_value: String, description: String, platinum_name: String) -> Button:
    var accent := class_accent_color(class_name_value)
    var button := Button.new()
    button.size = Vector2(274, 480)
    button.text = ""
    button.focus_mode = Control.FOCUS_NONE
    button.pivot_offset = button.size / 2.0
    button.clip_contents = true

    var normal := StyleBoxFlat.new()
    normal.bg_color = Color(0.018, 0.032, 0.062, 0.98)
    normal.border_color = accent.darkened(0.12)
    normal.set_border_width_all(3)
    normal.set_corner_radius_all(18)
    normal.shadow_color = Color(0,0,0,0.75)
    normal.shadow_size = 12
    button.add_theme_stylebox_override("normal", normal)

    var hover := normal.duplicate() as StyleBoxFlat
    hover.bg_color = Color(0.03, 0.052, 0.095, 1.0)
    hover.border_color = accent.lightened(0.18)
    hover.shadow_color = Color(accent.r, accent.g, accent.b, 0.45)
    hover.shadow_size = 18
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_stylebox_override("pressed", hover)

    var art := TextureRect.new()
    art.position = Vector2(27, 14)
    art.size = Vector2(220, 220)
    art.texture = load(leader_art_for(class_name_value)) as Texture2D
    art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    art.mouse_filter = Control.MOUSE_FILTER_IGNORE
    button.add_child(art)

    var gradient := GradientTexture2D.new()
    gradient.width = 256
    gradient.height = 112
    var g := Gradient.new()
    g.colors = PackedColorArray([Color(0,0,0,0), Color(0.01,0.02,0.05,0.96)])
    g.offsets = PackedFloat32Array([0.0, 1.0])
    gradient.gradient = g
    gradient.fill_from = Vector2(0.5, 0.0)
    gradient.fill_to = Vector2(0.5, 1.0)
    var fade := TextureRect.new()
    fade.position = Vector2(27, 164)
    fade.size = Vector2(220, 70)
    fade.texture = gradient
    fade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    button.add_child(fade)

    var class_label := Label.new()
    class_label.text = class_name_value.to_upper()
    class_label.position = Vector2(14, 240)
    class_label.size = Vector2(246, 42)
    class_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    class_label.add_theme_font_size_override("font_size", ui_font(27))
    class_label.add_theme_color_override("font_color", accent.lightened(0.22))
    class_label.add_theme_color_override("font_shadow_color", Color.BLACK)
    class_label.add_theme_constant_override("shadow_offset_x", 2)
    class_label.add_theme_constant_override("shadow_offset_y", 2)
    class_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    button.add_child(class_label)

    var leader_label := Label.new()
    leader_label.text = leader_name_for(class_name_value)
    leader_label.position = Vector2(14, 282)
    leader_label.size = Vector2(246, 26)
    leader_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    leader_label.add_theme_font_size_override("font_size", ui_font(15))
    leader_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.64))
    leader_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    button.add_child(leader_label)

    var description_label := Label.new()
    description_label.text = description
    description_label.position = Vector2(22, 316)
    description_label.size = Vector2(230, 50)
    description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    description_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    description_label.add_theme_font_size_override("font_size", ui_font(14))
    description_label.add_theme_color_override("font_color", Color(0.86, 0.91, 1.0))
    description_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    button.add_child(description_label)

    var divider := ColorRect.new()
    divider.position = Vector2(32, 372)
    divider.size = Vector2(210, 2)
    divider.color = Color(accent.r, accent.g, accent.b, 0.55)
    divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
    button.add_child(divider)

    var platinum_label := Label.new()
    platinum_label.text = "SIGNATURE PLATINUM\n" + platinum_name
    platinum_label.position = Vector2(16, 384)
    platinum_label.size = Vector2(242, 54)
    platinum_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    platinum_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    platinum_label.add_theme_font_size_override("font_size", ui_font(11))
    platinum_label.add_theme_color_override("font_color", Color(0.92, 0.76, 1.0))
    platinum_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    button.add_child(platinum_label)

    var select_label := Label.new()
    select_label.text = "BEGIN JOURNEY"
    select_label.position = Vector2(48, 442)
    select_label.size = Vector2(178, 30)
    select_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    select_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    select_label.add_theme_font_size_override("font_size", ui_font(15))
    select_label.add_theme_color_override("font_color", Color(1,1,1))
    select_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    button.add_child(select_label)

    button.mouse_entered.connect(func():
        var tween := button.create_tween()
        tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        tween.tween_property(button, "scale", Vector2(1.025, 1.025), 0.12)
    )
    button.mouse_exited.connect(func():
        var tween := button.create_tween()
        tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        tween.tween_property(button, "scale", Vector2.ONE, 0.12)
    )
    return button

func class_accent_color(class_name_value: String) -> Color:
    match class_name_value:
        "Serenity": return Color(0.26, 0.78, 0.94)
        "Courage": return Color(1.0, 0.34, 0.20)
        "Purpose": return Color(0.95, 0.68, 0.22)
        "Hope": return Color(0.72, 0.45, 1.0)
        _: return Color(0.55, 0.82, 0.58)

func choose_class(faction_name: String) -> void:
    selected_class = faction_name
    var classes := ["Serenity", "Courage", "Purpose", "Hope"]
    var idx: int = classes.find(faction_name)
    enemy_class = classes[(idx + 1) % classes.size()]
    if is_instance_valid(class_overlay): class_overlay.queue_free()
    start_game()


func setup_audio() -> void:
    var master_index: int = AudioServer.get_bus_index("Master")
    if master_index >= 0:
        AudioServer.set_bus_mute(master_index, false)
        AudioServer.set_bus_volume_db(master_index, 0.0)
    music_player = AudioStreamPlayer.new()
    music_player.volume_db = -1.0
    add_child(music_player)
    music_player_alt = AudioStreamPlayer.new()
    music_player_alt.volume_db = -40.0
    add_child(music_player_alt)
    sfx_player = AudioStreamPlayer.new()
    sfx_player.volume_db = 1.0
    add_child(sfx_player)
    sfx_pool.clear()
    for _i in range(5):
        var pooled := AudioStreamPlayer.new()
        pooled.volume_db = 1.0
        add_child(pooled)
        sfx_pool.append(pooled)
    ambience_player = AudioStreamPlayer.new()
    ambience_player.volume_db = -8.0
    add_child(ambience_player)
    voice_player = AudioStreamPlayer.new()
    voice_player.volume_db = 1.0
    add_child(voice_player)

func play_sfx(sound_name: String) -> void:
    var path := "res://assets/audio/%s.wav" % sound_name
    if not ResourceLoader.exists(path):
        return
    var target: AudioStreamPlayer = sfx_player
    for candidate in sfx_pool:
        if not candidate.playing:
            target = candidate
            break
    target.stream = load(path)
    target.play()

const LARGE_FOLLOWER_ATTACK_THRESHOLD := 5
const LARGE_FOLLOWER_HEALTH_THRESHOLD := 6

func attack_impact_sound(attacker_index: int, target_index: int, player_side: bool) -> String:
    # Leader hits always use the deeper impact layer regardless of attacker size.
    if target_index < 0:
        return "impact_leader_deep"
    var attack_board: Array = player_board if player_side else enemy_board
    var defend_board: Array = enemy_board if player_side else player_board
    var attacker: Dictionary = attack_board[attacker_index] if attacker_index >= 0 and attacker_index < attack_board.size() else {}
    var defender: Dictionary = defend_board[target_index] if target_index >= 0 and target_index < defend_board.size() else {}
    var is_large := int(attacker.get("attack", 0)) >= LARGE_FOLLOWER_ATTACK_THRESHOLD \
        or int(attacker.get("max_health", attacker.get("health", 0))) >= LARGE_FOLLOWER_HEALTH_THRESHOLD \
        or int(defender.get("attack", 0)) >= LARGE_FOLLOWER_ATTACK_THRESHOLD \
        or int(defender.get("max_health", defender.get("health", 0))) >= LARGE_FOLLOWER_HEALTH_THRESHOLD
    return "impact_large_follower" if is_large else "impact_follower_clean"

# Short in-character lines each leader can speak mid-battle. Kept purely
# text+audio (no gameplay effect) so the table feels populated by two people
# instead of two silent decks -- the recovery theme comes through in what
# each leader actually says at each moment (playing a card, landing a hit,
# running low on health, winning, or losing), not just in a rulebook.
const BATTLE_BARKS := {
    "Hope": {
        "play": ["Every card here is a reason to keep going.", "Small moves add up. Watch."],
        "attack": ["Hope doesn't hit soft.", "I'm not backing down from this."],
        "low_health": ["I've been lower than this and still stood up.", "This isn't the end of my story."],
        "victory": ["We made it through. Together.", "That's what hope looks like."],
        "defeat": ["This isn't over. Hope doesn't quit.", "I'll be back on my feet tomorrow."],
    },
    "Courage": {
        "play": ["Stepping up. Watch this.", "Fear doesn't get a vote here."],
        "attack": ["Stand my ground? Not today.", "That's what courage looks like."],
        "low_health": ["I've faced worse than this.", "Hurt, not broken."],
        "victory": ["Courage carried the day.", "Told you I wouldn't back down."],
        "defeat": ["I'll take the hit. I won't take the excuse.", "Down, not out."],
    },
    "Serenity": {
        "play": ["Patience. Let it land.", "Steady hands win this."],
        "attack": ["Calm doesn't mean passive.", "Quiet, then decisive."],
        "low_health": ["I'm still breathing. I'm still here.", "Stillness isn't weakness."],
        "victory": ["Peace, earned the hard way.", "That's the power of staying steady."],
        "defeat": ["I'll sit with this and come back stronger.", "Not every round is won. That's fine."],
    },
    "Purpose": {
        "play": ["Every move has a reason behind it.", "Building toward something. Watch."],
        "attack": ["This is what I'm fighting for.", "Purpose doesn't flinch."],
        "low_health": ["I know why I'm still standing.", "Too much left to build to quit now."],
        "victory": ["That's what purpose gets you.", "Built this win, one step at a time."],
        "defeat": ["This sets back the plan. Not the purpose.", "I'll rebuild from here."],
    },
}

func battle_bark_voice_folder(faction: String) -> String:
    return faction.to_lower()

# Fires a leader's line for the given moment (play/attack/low_health/victory/
# defeat): shows a speech bubble over their portrait and, if a matching
# pre-recorded clip exists, plays it through the shared voice_player. Never
# awaited by callers -- it runs alongside the battle instead of pausing it,
# the same way a quip should never block the game waiting for it to finish.
func play_battle_bark(leader: Control, faction: String, category: String, player_side: bool, force: bool = false) -> void:
    if not is_instance_valid(leader) or not BATTLE_BARKS.has(faction):
        return
    var lines: Array = BATTLE_BARKS[faction].get(category, [])
    if lines.is_empty():
        return
    var now := Time.get_ticks_msec() / 1000.0
    if not force and now - last_bark_at < BATTLE_BARK_COOLDOWN:
        return
    if category == "play" and randf() > BATTLE_BARK_PLAY_CHANCE:
        return
    last_bark_at = now
    var variant := randi() % lines.size()
    var line := str(lines[variant])
    var accent := class_accent_color(faction)
    leader_speech_bubble(leader, line, accent)
    var path := "res://assets/audio/voices/battle/%s/%s_%d.wav" % [battle_bark_voice_folder(faction), category, variant + 1]
    if ResourceLoader.exists(path) and is_instance_valid(voice_player) and not voice_player.playing:
        voice_player.stream = load(path)
        voice_player.play()

# A wider, word-wrapped cousin of leader_emote() for actual spoken lines
# instead of single glyphs -- same pop-in/drift-up/fade choreography so it
# reads as part of the same visual language, just sized for a sentence.
func leader_speech_bubble(leader: Control, text: String, accent: Color) -> void:
    if not is_instance_valid(leader):
        return
    var bubble_width := 220.0
    var bubble_height := 64.0
    var bubble := Panel.new()
    bubble.size = Vector2(bubble_width, bubble_height)
    var bubble_style := StyleBoxFlat.new()
    bubble_style.bg_color = Color(0.03, 0.045, 0.08, 0.94)
    bubble_style.border_color = accent
    bubble_style.set_border_width_all(2)
    bubble_style.set_corner_radius_all(12)
    bubble_style.shadow_color = Color(0, 0, 0, 0.5)
    bubble_style.shadow_size = 6
    bubble.add_theme_stylebox_override("panel", bubble_style)
    bubble.z_index = 400
    bubble.pivot_offset = Vector2(bubble_width * 0.5, bubble_height * 0.5)
    bubble.scale = Vector2(0.3, 0.3)
    bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
    bubble.position = leader.global_position + Vector2(leader.size.x * 0.5 - bubble_width * 0.5, -bubble_height - 10)
    if not safe_add_child(self, bubble): return
    var line := Label.new()
    line.text = text
    line.position = Vector2(10, 6)
    line.size = Vector2(bubble_width - 20, bubble_height - 12)
    line.add_theme_font_size_override("font_size", ui_font(13))
    line.add_theme_color_override("font_color", Color(0.95, 0.96, 0.98))
    line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    bubble.add_child(line)
    var pop := create_tween()
    pop.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    pop.tween_property(bubble, "scale", Vector2(1.05, 1.05), 0.16)
    pop.tween_property(bubble, "scale", Vector2(1.0, 1.0), 0.10)
    await get_tree().create_timer(2.6).timeout
    if not is_instance_valid(bubble):
        return
    var fade := create_tween()
    fade.tween_property(bubble, "modulate:a", 0.0, 0.35)
    await fade.finished
    if is_instance_valid(bubble):
        bubble.queue_free()

func signature_voice_key(card_name: String, attack_line: bool = false) -> String:
    var base := card_name.to_lower().replace(" ", "_")
    return base + ("_attack" if attack_line else "")

# Signature Platinum voice clips are organized by class under
# assets/audio/voices/cards/<folder>/ so they sit next to their leader's
# other assets instead of one flat folder.
func signature_voice_folder(card_name: String) -> String:
    match card_name:
        "Beacon of Hope": return "hope"
        "Rally the Free": return "courage"
        "Inner Peace": return "serenity"
        "Walking Free": return "purpose"
        "The Sponsor": return "neutral"
        _: return "neutral"

func play_signature_voice(card_name: String, player_side: bool, attack_line: bool = false) -> void:
    var side_prefix := "player" if player_side else "enemy"
    var key := side_prefix + ":" + signature_voice_key(card_name, attack_line)
    if signature_voice_played.has(key):
        return
    var path := "res://assets/audio/voices/cards/%s/%s.wav" % [signature_voice_folder(card_name), signature_voice_key(card_name, attack_line)]
    if not ResourceLoader.exists(path) or not is_instance_valid(voice_player):
        return
    signature_voice_played[key] = true
    var old_music_db: float = music_player.volume_db if is_instance_valid(music_player) else -5.0
    if is_instance_valid(music_player):
        music_player.volume_db = old_music_db - 10.0
    voice_player.stream = load(path)
    voice_player.play()
    # Never let a malformed or interrupted voice asset lock the battle coroutine.
    var elapsed: float = 0.0
    var max_wait: float = 3.5
    while is_instance_valid(voice_player) and voice_player.playing and elapsed < max_wait:
        await get_tree().process_frame
        elapsed += get_process_delta_time()
    if is_instance_valid(voice_player) and voice_player.playing:
        voice_player.stop()
    if is_instance_valid(music_player):
        music_player.volume_db = old_music_db

func find_board_unit_index(unit: Dictionary, player_side: bool) -> int:
    var board: Array = player_board if player_side else enemy_board
    var direct_index: int = board.find(unit)
    if direct_index >= 0:
        return direct_index
    # Fallback for Dictionaries that were copied or normalized after entering play.
    var wanted_name: String = str(unit.get("name", ""))
    var wanted_turn: int = int(unit.get("summoned_turn", -999))
    for i in range(board.size() - 1, -1, -1):
        var candidate: Dictionary = board[i]
        if str(candidate.get("name", "")) == wanted_name and int(candidate.get("summoned_turn", -998)) == wanted_turn:
            return i
    return -1

func free_evolve_signature(unit: Dictionary, player_side: bool) -> void:
    var board: Array = player_board if player_side else enemy_board
    var index: int = find_board_unit_index(unit, player_side)
    if index < 0:
        await show_vfx("EVOLUTION RECOVERED", area_center(player_side), Color(1.0, 0.72, 0.22))
        return
    var live_unit: Dictionary = board[index]
    if bool(live_unit.get("evolved", false)):
        return
    # Apply the gameplay state first so a visual/audio interruption can never freeze or cancel the evolution.
    live_unit["attack"] = int(live_unit.get("attack", 0)) + 2
    live_unit["health"] = int(live_unit.get("health", 0)) + 2
    live_unit["max_health"] = int(live_unit.get("max_health", live_unit.get("health", 0))) + 2
    live_unit["evolved"] = true
    live_unit["can_attack"] = true
    live_unit["evolved_this_turn"] = true
    board[index] = live_unit
    # Dictionaries are reference types. Clearing `unit` here also cleared the
    # live board entry and produced the blank 0/0 card. Keep the existing
    # battlefield dictionary intact and animate it in place.
    await play_evolution_animation(index, 3, player_side)
    await show_vfx("SIGNATURE EVOLUTION +2/+2", area_center(player_side), class_accent_color(str(live_unit.get("faction", "Purpose"))))


func play_sponsor_evolution_animation(unit: Dictionary, player_side: bool) -> void:
    var board: Array = player_board if player_side else enemy_board
    var index: int = find_board_unit_index(unit, player_side)
    if index < 0 or bool(board[index].get("evolved", false)):
        return
    var area: Control = player_board_area if player_side else enemy_board_area
    var card_view: CardView = find_card_view_for_board_index(area, index)
    if card_view == null:
        return
    unit = board[index]

    busy = true
    var old_music_db := music_player.volume_db if is_instance_valid(music_player) else -5.0
    if is_instance_valid(music_player):
        music_player.volume_db = old_music_db - 12.0

    card_view.z_index = 1400
    var original_position := card_view.position
    var original_scale    := card_view.scale
    var screen_center     := Vector2(640.0, 360.0)
    # Card rests left-of-centre so the sponsee portrait has room on the right.
    var card_dest := screen_center - card_view.size * 0.5 - area.global_position + Vector2(-120, 0)

    # ── Dark overlay ────────────────────────────────────────────────────────
    var dimmer := ColorRect.new()
    dimmer.color         = Color(0.01, 0.012, 0.025, 0.0)
    dimmer.z_index       = 1200
    dimmer.mouse_filter  = Control.MOUSE_FILTER_IGNORE
    dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(dimmer)

    # ── Cinematic background (Sponsor's scene) ──────────────────────────────
    var cinematic_bg := TextureRect.new()
    var _cin_tex := load("res://assets/cards/full/jd-080-cinematic.jpg") as Texture2D
    cinematic_bg.texture     = _cin_tex
    cinematic_bg.z_index     = 1205
    cinematic_bg.modulate    = Color(1.0, 1.0, 1.0, 0.0)
    cinematic_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    cinematic_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    cinematic_bg.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
    cinematic_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    add_child(cinematic_bg)

    # ── Sponsee portrait (slides in from the right) ─────────────────────────
    var sponsee_preview  := card("Sponsee", 2, 2, 2, "Universal", "Token", "sponsee", 0, "", "hands")
    var sponsee_portrait := build_art_medallion(
        CardArt.resolve(sponsee_preview), Vector2(920, 180), Vector2(220, 300),
        Color(1.0, 0.88, 0.44))
    sponsee_portrait.modulate = Color(1, 1, 1, 0)
    sponsee_portrait.z_index  = 1310
    add_child(sponsee_portrait)

    # ── Quote / title text ──────────────────────────────────────────────────
    var line_label := Label.new()
    line_label.text        = "\"YOU ARE NEVER ALONE.\""
    line_label.position    = Vector2(160, 505)
    line_label.size        = Vector2(960, 60)
    line_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    line_label.add_theme_font_size_override("font_size", ui_font(40))
    line_label.add_theme_color_override("font_color",        Color(1.0, 0.95, 0.72))
    line_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.90))
    line_label.add_theme_constant_override("shadow_offset_x", 3)
    line_label.add_theme_constant_override("shadow_offset_y", 4)
    line_label.modulate.a  = 0.0
    line_label.z_index     = 1380
    add_child(line_label)

    var title_label := Label.new()
    title_label.text       = "GUIDANCE BECOMES FREEDOM"
    title_label.position   = Vector2(200, 576)
    title_label.size       = Vector2(880, 36)
    title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title_label.add_theme_font_size_override("font_size", ui_font(20))
    title_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.30))
    title_label.modulate.a = 0.0
    title_label.z_index    = 1380
    add_child(title_label)

    # ── Phase 1 — dim + cinematic rise + card zoom ──────────────────────────
    var rise := create_tween().set_parallel(true)
    rise.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
    rise.tween_property(dimmer,       "color:a",           0.90,             0.35)
    rise.tween_property(cinematic_bg, "modulate:a",        0.55,             0.50)
    rise.tween_property(card_view,    "position",          card_dest,        0.40)
    rise.tween_property(card_view,    "scale",  Vector2(2.0, 2.0),           0.40)
    await rise.finished

    # ── Phase 2 — white flash + sunburst rays ──────────────────────────────
    # White flash: full-screen, very brief — the card "transforms" in the light.
    var flash := ColorRect.new()
    flash.color       = Color(1.0, 1.0, 1.0, 0.0)
    flash.z_index     = 1450
    flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
    flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(flash)
    var flash_t := create_tween()
    flash_t.set_trans(Tween.TRANS_QUAD)
    flash_t.tween_property(flash, "color:a", 0.92, 0.08)
    flash_t.tween_property(flash, "color:a", 0.0,  0.22)
    flash_t.finished.connect(flash.queue_free)

    play_sfx("sponsor_evolve")

    # Sunburst — 16 thin gold rays expanding from the card center.
    # Each ray is a ColorRect whose pivot is at its own top-left, rotated
    # so it points outward from screen_center.
    var burst_origin := screen_center + Vector2(-120, 0)  # matches card_dest center
    var ray_nodes: Array = []
    for ri in range(16):
        var ray := ColorRect.new()
        ray.size          = Vector2(4, 260)
        ray.color         = Color(1.0, 0.84, 0.22, 0.80)
        ray.pivot_offset  = Vector2(2, 0)
        ray.position      = burst_origin - Vector2(2, 0)
        ray.rotation      = ri * TAU / 16.0
        ray.z_index       = 1240
        ray.mouse_filter  = Control.MOUSE_FILTER_IGNORE
        add_child(ray)
        ray_nodes.append(ray)
        var rt := create_tween().set_parallel(true)
        rt.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
        rt.tween_property(ray, "color:a",            0.0, 0.55).set_delay(0.08)
        rt.finished.connect(ray.queue_free)

    # Concentric glow rings (3 circles made from square ColorRects with
    # modulate — each offset so they look centred on burst_origin).
    var ring_colors := [Color(1.0, 0.88, 0.40, 0.30),
                        Color(1.0, 0.72, 0.18, 0.18),
                        Color(0.90, 0.60, 0.10, 0.10)]
    var ring_nodes: Array = []
    for rk in range(3):
        var sz := float(200 + rk * 130)
        var ring := ColorRect.new()
        ring.size         = Vector2(sz, sz)
        ring.color        = ring_colors[rk]
        ring.position     = burst_origin - Vector2(sz * 0.5, sz * 0.5)
        ring.z_index      = 1215 + rk
        ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(ring)
        ring_nodes.append(ring)
        # Pulse outward then fade
        var rnt := create_tween().set_parallel(true)
        rnt.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
        rnt.tween_property(ring, "scale",      Vector2(1.6, 1.6), 0.70)
        rnt.tween_property(ring, "color:a",    0.0,               0.60)
        rnt.finished.connect(ring.queue_free)

    spawn_sparkle_burst(burst_origin, 20,
        [Color(1.0, 0.86, 0.34), Color(1.0, 1.0, 1.0), Color(1.0, 0.60, 0.10)], self, 110.0)
    await get_tree().create_timer(0.30).timeout

    # ── Phase 3 — voice + quote ────────────────────────────────────────────
    await play_signature_voice("The Sponsor", player_side, false)
    var quote_t := create_tween()
    quote_t.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    quote_t.tween_property(line_label, "modulate:a", 1.0, 0.35)
    await quote_t.finished

    # ── Phase 4 — sponsee portrait slides in + title + connection spark ────
    # Slide sponsee in from the right
    var connect_t := create_tween().set_parallel(true)
    connect_t.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    connect_t.tween_property(sponsee_portrait, "position",    Vector2(820, 180), 0.40)
    connect_t.tween_property(sponsee_portrait, "modulate:a",  1.0,               0.35)
    connect_t.set_trans(Tween.TRANS_QUAD)
    connect_t.tween_property(title_label,      "modulate:a",  1.0,               0.30)
    await connect_t.finished

    # Connection spark — runs from card to sponsee in a brief burst
    spawn_sparkle_burst(burst_origin + Vector2(160, 0), 10,
        [Color(1.0, 0.86, 0.34), Color(1.0, 1.0, 1.0)], self, 60.0)
    spawn_sparkle_burst(Vector2(870, 330), 10,
        [Color(1.0, 0.86, 0.34), Color(1.0, 1.0, 1.0)], self, 60.0)
    await get_tree().create_timer(0.45).timeout

    # ── Apply evolution stats ───────────────────────────────────────────────
    unit["attack"]       = int(unit.get("attack", 0)) + 2
    unit["health"]       = int(unit.get("health", 0)) + 2
    unit["max_health"]   = int(unit.get("max_health", unit.get("health", 0))) + 2
    unit["evolved"]      = true
    unit["can_attack"]   = true
    unit["evolved_this_turn"] = true
    board[index] = unit

    await create_sponsee(player_side)

    # ── Phase 5 — everything fades out + card returns ──────────────────────
    var return_t := create_tween().set_parallel(true)
    return_t.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
    return_t.tween_property(card_view,        "position",    original_position, 0.30)
    return_t.tween_property(card_view,        "scale",       original_scale,    0.30)
    return_t.tween_property(dimmer,           "color:a",     0.0,               0.30)
    return_t.tween_property(cinematic_bg,     "modulate:a",  0.0,               0.28)
    return_t.tween_property(sponsee_portrait, "modulate:a",  0.0,               0.24)
    return_t.tween_property(line_label,       "modulate:a",  0.0,               0.24)
    return_t.tween_property(title_label,      "modulate:a",  0.0,               0.24)
    await return_t.finished

    card_view.z_index = 0
    for n in [dimmer, cinematic_bg, sponsee_portrait, line_label, title_label]:
        if is_instance_valid(n):
            n.queue_free()
    if is_instance_valid(music_player):
        music_player.volume_db = old_music_db
    busy = false
    await show_vfx("THE SPONSOR — YOU NEVER WALK ALONE", area_center(player_side), Color(1.0, 0.84, 0.34))

func buff_deck_followers(player_side: bool, faction: String, amount: int) -> void:
    var deck: Array = player_deck if player_side else enemy_deck
    for deck_card in deck:
        if str(deck_card.get("faction", "")) != faction:
            continue
        if bool(deck_card.get("is_amulet", false)):
            continue
        deck_card["attack"] = int(deck_card.get("attack", 0)) + amount
        deck_card["health"] = int(deck_card.get("health", 0)) + amount
        deck_card["max_health"] = int(deck_card.get("max_health", deck_card.get("health", 0))) + amount

func create_inspired_volunteer(player_side: bool) -> void:
    var board: Array = player_board if player_side else enemy_board
    if follower_count(board) >= MAX_BOARD:
        return
    var volunteer := card("Inspired Volunteer", 2, 2, 3, "Hope", "Token", "heal_grows", 0, "Whenever your leader is healed, gain +1/+1.", "hands", "jd-131")
    volunteer["can_attack"] = false
    volunteer["summoned_turn"] = turn_number
    board.append(volunteer)

func play_class_battle_ambience() -> void:
    if not is_instance_valid(ambience_player):
        return
    var cue := "battle_ambience_%s" % selected_class.to_lower()
    var path := "res://assets/audio/%s.wav" % cue
    if ResourceLoader.exists(path):
        ambience_player.stream = load(path)
        ambience_player.play()

func set_battle_music(track_name: String) -> void:
    var active_player: AudioStreamPlayer = music_player_alt if music_using_alt else music_player
    if current_music == track_name and is_instance_valid(active_player) and active_player.playing:
        return
    var fixed_name: String = track_name.replace("_v2", "_fixed")
    var path := "res://assets/audio/%s.ogg" % fixed_name
    var loaded_stream: AudioStream = load(path) as AudioStream
    if loaded_stream == null:
        path = "res://assets/audio/%s.wav" % track_name
        loaded_stream = load(path) as AudioStream
    if loaded_stream == null:
        push_warning("Battle music missing: %s" % path)
        return
    var incoming: AudioStreamPlayer = music_player if music_using_alt else music_player_alt
    var outgoing: AudioStreamPlayer = music_player_alt if music_using_alt else music_player
    if loaded_stream is AudioStreamWAV:
        var looped_stream: AudioStreamWAV = loaded_stream.duplicate(true) as AudioStreamWAV
        looped_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
        incoming.stream = looped_stream
    else:
        incoming.stream = loaded_stream
    incoming.volume_db = -32.0
    incoming.play()
    current_music = track_name
    music_using_alt = not music_using_alt
    var fade := create_tween().set_parallel(true)
    fade.tween_property(incoming, "volume_db", -0.5, 0.65)
    if is_instance_valid(outgoing) and outgoing.playing:
        fade.tween_property(outgoing, "volume_db", -32.0, 0.65)
        fade.chain().tween_callback(outgoing.stop)

func update_dynamic_music() -> void:
    var desired := "battle_early_v2"
    if player_health <= 7 or enemy_health <= 7:
        desired = "battle_critical_v2"
    elif turn_number >= 8:
        desired = "battle_late_v2"
    elif turn_number >= 4:
        desired = "battle_mid_v2"
    set_battle_music(desired)

func leader_feedback(leader: Control, damage: int, healing: bool = false) -> void:
    play_sfx("heal" if healing else ("hit_heavy" if damage >= 4 else "hit_light"))
    var start := leader.position
    var tween := create_tween()
    if healing:
        tween.tween_property(leader, "modulate", Color(0.55, 1.35, 0.70), 0.10)
        tween.tween_property(leader, "modulate", Color.WHITE, 0.22)
        leader_emote(leader, "♥", Color(0.55, 1.0, 0.70))
        _spawn_heal_particles(leader.global_position + leader.size * 0.5)
    else:
        tween.tween_property(leader, "modulate", Color(1.65, 0.35, 0.35), 0.06)
        tween.tween_property(leader, "position", start + Vector2(10, 0), 0.04)
        tween.tween_property(leader, "position", start - Vector2(10, 0), 0.04)
        tween.tween_property(leader, "position", start, 0.04)
        tween.tween_property(leader, "modulate", Color.WHITE, 0.15)
        leader_emote(leader, "!" if damage < 4 else "✦", Color(1.0, 0.42, 0.32))

# Small floating reaction bubble ("emote") above a leader portrait — pops in,
# drifts up, and fades. Kept to the handful of glyphs already proven to
# render cleanly in this project's default font (♥ ✦ ★ • and plain ASCII),
# since the game ships no custom/emoji font and untested glyphs render as
# missing-character boxes.
func leader_emote(leader: Control, symbol: String, color: Color) -> void:
    if not is_instance_valid(leader):
        return
    var bubble := Label.new()
    bubble.text = symbol
    bubble.z_index = 400
    bubble.add_theme_font_size_override("font_size", ui_font(26))
    bubble.add_theme_color_override("font_color", color)
    bubble.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
    bubble.add_theme_constant_override("shadow_offset_x", 2)
    bubble.add_theme_constant_override("shadow_offset_y", 2)
    bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
    bubble.pivot_offset = Vector2(11, 14)
    bubble.scale = Vector2(0.3, 0.3)
    bubble.position = leader.global_position + Vector2(leader.size.x * 0.5 - 11, -14)
    add_child(bubble)
    var pop := create_tween()
    pop.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    pop.tween_property(bubble, "scale", Vector2(1.25, 1.25), 0.16)
    pop.tween_property(bubble, "scale", Vector2(1.0, 1.0), 0.10)
    var drift := create_tween().set_parallel(true)
    drift.tween_property(bubble, "position:y", bubble.position.y - 36, 0.75)
    drift.tween_property(bubble, "modulate:a", 0.0, 0.4).set_delay(0.4)
    await drift.finished
    if is_instance_valid(bubble):
        bubble.queue_free()

# Subtle looping "breathing" animation so leader portraits feel alive on the
# battlefield instead of sitting as a static image. Runs on the portrait
# child (not the leader Button itself), which stays free for the separate
# hit-flinch and victory/defeat scale tweens on the Button to run without
# fighting over the same "scale" property.
func start_leader_idle(portrait: TextureRect) -> void:
    portrait.pivot_offset = portrait.size * 0.5
    # Breathing — slow scale pulse so the portrait feels alive.
    var idle := create_tween().set_loops().bind_node(portrait)
    idle.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    idle.tween_property(portrait, "scale", Vector2(1.040, 1.040), 1.8)
    idle.tween_property(portrait, "scale", Vector2(1.000, 1.000), 1.8)
    # Subtle lateral drift — character sways very slightly inside the frame.
    var drift := create_tween().set_loops().bind_node(portrait)
    drift.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    drift.tween_property(portrait, "position:x",  2.5, 2.6)
    drift.tween_property(portrait, "position:x", -2.0, 2.6)
    drift.tween_property(portrait, "position:x",  0.0, 2.6)

## Applies class-specific background tint and a pulsing aura border to a leader.
## Must be called AFTER update_leader_visual() so faction is known.
func _start_leader_class_aura(leader: Button, faction_name: String) -> void:
    var old := leader.get_node_or_null("ClassAuraBorder")
    if is_instance_valid(old):
        old.queue_free()

    var ac := class_accent_color(faction_name)

    # Class-tinted atmospheric background.
    var aura_bg := leader.get_node_or_null("AuraBg") as ColorRect
    if aura_bg != null:
        aura_bg.color = Color(ac.r * 0.10, ac.g * 0.08, ac.b * 0.14, 1.0)

    # Tint the bottom scrim to match.
    var scrim := leader.get_node_or_null("BottomScrim") as ColorRect
    if scrim != null:
        scrim.color = Color(ac.r * 0.06, ac.g * 0.05, ac.b * 0.10, 0.92)

    # Class-coloured accent bar.
    var accent := leader.get_node_or_null("AccentBar") as ColorRect
    if accent != null:
        accent.color = ac

    # Glowing border panel that pulses in class colour.
    var border := Panel.new()
    border.name = "ClassAuraBorder"
    border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    border.mouse_filter = Control.MOUSE_FILTER_IGNORE
    border.z_index = 90
    var bs := StyleBoxFlat.new()
    bs.bg_color       = Color(0, 0, 0, 0)
    bs.border_color   = Color(ac.r, ac.g, ac.b, 0.60)
    bs.set_border_width_all(3)
    bs.set_corner_radius_all(0)
    bs.shadow_color   = Color(ac.r, ac.g, ac.b, 0.40)
    bs.shadow_size    = 22
    border.add_theme_stylebox_override("panel", bs)
    leader.add_child(border)

    # Pulse speed varies by class personality.
    var speed: float = 1.9  # Purpose: disciplined default
    if faction_name == "Courage":  speed = 1.0   # urgent, rapid flicker
    elif faction_name == "Hope":   speed = 1.6   # warm, steady
    elif faction_name == "Serenity": speed = 2.6 # slow, meditative
    var pulse := create_tween().set_loops().bind_node(leader)
    pulse.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    pulse.tween_property(border, "modulate:a", 0.28, speed)
    pulse.tween_property(border, "modulate:a", 1.00, speed)

# Leader portraits are square, full-scene paintings with the character in the
# top ~60% of the canvas (see menu.gd: class_leader_texture, same fix applied
# here so battle portraits match the framing used everywhere else in the app).
func leader_portrait_texture(path: String) -> Texture2D:
    var base := load(path) as Texture2D
    if base == null:
        return null
    var atlas := AtlasTexture.new()
    atlas.atlas = base
    atlas.region = Rect2(0, 0, base.get_width(), base.get_height() * 0.6)
    return atlas

func build_ui() -> void:
    # Neutral arena background: no embedded menus or duplicate UI artwork.
    battlefield_background = TextureRect.new()
    battlefield_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    battlefield_background.texture = svg_texture(battlefield_svg())
    battlefield_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    battlefield_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    battlefield_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(battlefield_background)

    var field_shade := ColorRect.new()
    field_shade.color = Color(0.01, 0.02, 0.04, 0.10)
    field_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    field_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(field_shade)

    # A slim header bar grounds the title and HOME/RESTART controls instead of
    # leaving them floating loose over the battlefield artwork.
    var header_bar := Panel.new()
    header_bar.position = Vector2(0, 0)
    header_bar.size = Vector2(1280, 54)
    header_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var header_style := StyleBoxFlat.new()
    header_style.bg_color = Color(0.03, 0.045, 0.075, 0.82)
    header_style.set_border_width(SIDE_BOTTOM, 2)
    header_style.border_color = Color(0.96, 0.83, 0.45, 0.45)
    header_style.shadow_color = Color(0, 0, 0, 0.5)
    header_style.shadow_size = 12
    header_bar.add_theme_stylebox_override("panel", header_style)
    add_child(header_bar)

    var title := Label.new()
    title.text = "WALKING FREE CCG"
    title.position = Vector2(430, 8)
    title.size = Vector2(420, 38)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", ui_font(27))
    title.add_theme_color_override("font_color", Color(0.96, 0.83, 0.45))
    title.add_theme_color_override("font_shadow_color", Color(0.05, 0.03, 0.02, 0.85))
    title.add_theme_constant_override("shadow_offset_x", 2)
    title.add_theme_constant_override("shadow_offset_y", 2)
    add_child(title)

    var title_underline := ColorRect.new()
    title_underline.position = Vector2(560, 40)
    title_underline.size = Vector2(160, 2)
    title_underline.color = Color(0.96, 0.83, 0.45, 0.55)
    title_underline.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(title_underline)

    enemy_hand_area = Control.new(); enemy_hand_area.position = Vector2(355, 34); enemy_hand_area.size = Vector2(570, 70); add_child(enemy_hand_area)
    enemy_board_area = Control.new(); enemy_board_area.position = Vector2(245, 82); enemy_board_area.size = Vector2(790, 165); enemy_board_area.z_index = 60; enemy_board_area.clip_contents = false; add_child(enemy_board_area)
    # Amulet rows sit flush against the inside edge of each board so they
    # never occupy the open battlefield center.  Empty slots are hidden so
    # "RECOVERY SKILL" placeholders never clutter the screen.
    enemy_amulet_area = Control.new(); enemy_amulet_area.position = Vector2(245, 240); enemy_amulet_area.size = Vector2(790, 54); enemy_amulet_area.z_index = 65; enemy_amulet_area.clip_contents = false; add_child(enemy_amulet_area)
    player_amulet_area = Control.new(); player_amulet_area.position = Vector2(245, 365); player_amulet_area.size = Vector2(790, 54); player_amulet_area.z_index = 65; player_amulet_area.clip_contents = false; add_child(player_amulet_area)
    player_board_area = Control.new(); player_board_area.position = Vector2(245, 365); player_board_area.size = Vector2(790, 165); player_board_area.z_index = 60; player_board_area.clip_contents = false; add_child(player_board_area)
    # Keep the hand in a dedicated bottom tray so it never covers the battlefield.
    player_hand_area = Control.new(); player_hand_area.position = Vector2(150, 600); player_hand_area.size = Vector2(880, 115); player_hand_area.clip_contents = false; player_hand_area.z_index = 120; add_child(player_hand_area)

    enemy_leader = make_leader("OPPONENT", Vector2(24, 92), false)
    enemy_leader.pressed.connect(func(): leader_clicked(false))
    add_child(enemy_leader)
    player_leader = make_leader("YOU", Vector2(1062, 335), true)
    player_leader.pressed.connect(func(): leader_clicked(true))
    add_child(player_leader)

    # Hang each HP badge off the bottom-right corner of its own leader frame.
    # IMPORTANT: these must NOT be children of the leader Button — make_leader()
    # sets leader.clip_contents = true so its own portrait art doesn't bleed
    # out, and a badge offset far enough to "hang off the corner" fell mostly
    # outside the leader's own (195x185) rect, so it was being silently
    # clipped away entirely. Parenting to self (unclipped) with an absolute
    # position fixes that; z_index keeps it above board art either way.
    enemy_health_label = make_hp_label(enemy_leader.position + Vector2(118, 153), class_accent_color(enemy_class))
    enemy_health_label.z_index = 130
    add_child(enemy_health_label)
    player_health_label = make_hp_label(player_leader.position + Vector2(118, 153), class_accent_color(selected_class))
    player_health_label.z_index = 130
    add_child(player_health_label)

    build_play_point_counter()
    # The old turn_label was a plain unstyled Label wedged against the bottom
    # edge of the momentum button and doubled as the hand-size counter too —
    # easy to miss and easy to misread. Give the turn number its own bold
    # badge up near the header where players are already looking, and keep
    # the hand count as a separate, smaller label near the hand tray.
    var turn_panel := Panel.new()
    turn_panel.position = Vector2(555, 60)
    turn_panel.size = Vector2(170, 44)
    turn_panel.z_index = 140
    var turn_panel_style := StyleBoxFlat.new()
    turn_panel_style.bg_color = Color(0.03, 0.045, 0.08, 0.94)
    turn_panel_style.border_color = Color(0.96, 0.83, 0.45, 0.9)
    turn_panel_style.set_border_width_all(2)
    turn_panel_style.set_corner_radius_all(20)
    turn_panel_style.shadow_color = Color(0, 0, 0, 0.5)
    turn_panel_style.shadow_size = 8
    turn_panel.add_theme_stylebox_override("panel", turn_panel_style)
    add_child(turn_panel)
    turn_label = Label.new()
    turn_label.position = Vector2(0, 0)
    turn_label.size = Vector2(170, 44)
    turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    turn_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    turn_label.add_theme_font_size_override("font_size", ui_font(19))
    turn_label.add_theme_color_override("font_color", Color(0.99, 0.93, 0.72))
    turn_panel.add_child(turn_label)

    hand_count_label = Label.new()
    hand_count_label.position = Vector2(150, 580)
    hand_count_label.size = Vector2(200, 24)
    hand_count_label.add_theme_font_size_override("font_size", ui_font(13))
    hand_count_label.add_theme_color_override("font_color", Color(0.82, 0.88, 0.96))
    add_child(hand_count_label)

    status_label = Label.new(); status_label.position = Vector2(280, 276); status_label.size = Vector2(720, 32); status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; status_label.add_theme_font_size_override("font_size", ui_font(16)); status_label.add_theme_color_override("font_color", Color(0.96, 0.91, 0.72)); add_child(status_label)

    end_turn_button = Button.new(); end_turn_button.text = "END TURN"; end_turn_button.position = Vector2(1075, 278); end_turn_button.size = Vector2(170, 58); end_turn_button.add_theme_font_size_override("font_size", ui_font(19)); end_turn_button.pressed.connect(end_player_turn); add_child(end_turn_button)

    build_turn_timer()
    build_momentum_control()
    build_evolution_panel()

    var restart := _make_header_pill_button("RESTART", Vector2(1165, 10)); restart.tooltip_text = "Restart this battle"; restart.pressed.connect(func(): get_tree().reload_current_scene()); add_child(restart)
    var home := _make_header_pill_button("HOME", Vector2(1062, 10)); home.pressed.connect(func():
        var _nav := ConfigFile.new(); _nav.set_value("nav","return_from_battle",true); _nav.save("user://nav.cfg")
        get_tree().change_scene_to_file("res://main.tscn")); add_child(home)

    overlay = ColorRect.new(); overlay.color = Color(0, 0, 0, 0.68); overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); overlay.visible = false; overlay.mouse_filter = Control.MOUSE_FILTER_STOP; add_child(overlay)
    apply_mobile_touch_targets()

func apply_mobile_touch_targets() -> void:
    if not is_mobile_device():
        return
    if is_instance_valid(end_turn_button):
        end_turn_button.size = Vector2(190, 68)
        end_turn_button.position = Vector2(1055, 268)
    if is_instance_valid(player_leader):
        player_leader.scale = Vector2(1.08, 1.08)
    if is_instance_valid(enemy_leader):
        enemy_leader.scale = Vector2(1.08, 1.08)

func build_play_point_counter() -> void:
    var pp_panel := Panel.new()
    pp_panel.position = Vector2(1028, 548)
    pp_panel.size = Vector2(232, 100)
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.025, 0.075, 0.11, 0.96)
    style.border_color = Color(0.34, 0.82, 1.0)
    style.set_border_width_all(3)
    style.set_corner_radius_all(14)
    style.shadow_color = Color(0, 0, 0, 0.65)
    style.shadow_size = 10
    pp_panel.add_theme_stylebox_override("panel", style)
    add_child(pp_panel)

    var pp_title := Label.new()
    pp_title.text = "PLAY POINTS"
    pp_title.position = Vector2(10, 5)
    pp_title.size = Vector2(212, 24)
    pp_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    pp_title.add_theme_font_size_override("font_size", ui_font(14))
    pp_title.add_theme_color_override("font_color", Color(0.72, 0.92, 1.0))
    pp_panel.add_child(pp_title)

    mana_label = Label.new()
    mana_label.position = Vector2(10, 27)
    mana_label.size = Vector2(212, 30)
    mana_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    mana_label.add_theme_font_size_override("font_size", ui_font(24))
    mana_label.add_theme_color_override("font_color", Color(0.82, 0.96, 1.0))
    pp_panel.add_child(mana_label)

    pp_pips.clear()
    for i in range(MAX_MANA):
        var pip := ColorRect.new()
        pip.position = Vector2(13 + i * 20, 65)
        pip.size = Vector2(14, 14)
        pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
        pp_panel.add_child(pip)
        pp_pips.append(pip)

func leader_name_for(faction_name: String) -> String:
    match faction_name:
        "Serenity": return "Aurelia, Voice of Calm"
        "Courage": return "Kael, Flame Unbound"
        "Purpose": return "Orin, Grand Architect"
        "Hope": return "Lyra, Dawn Returned"
        "Sponsor": return "The Sponsor"
        _: return "The First Traveler"

func leader_art_for(faction_name: String) -> String:
    match faction_name:
        "Serenity": return "res://assets/leaders/serenity.png"
        "Courage": return "res://assets/leaders/courage.png"
        "Purpose": return "res://assets/leaders/purpose.png"
        "Hope": return "res://assets/leaders/hope.png"
        # The Sponsor has no full-scene leader painting -- he uses his own
        # card's art directly (see build_sponsor_trial_deck / JD-080).
        "Sponsor": return "res://assets/cards/full/jd-080.jpg"
        _: return "res://assets/leaders/player.png"

func update_leader_visual(leader: Button, faction_name: String, player_side: bool) -> void:
    # Drive the single authoritative LeaderView — same layered art, same registry,
    # same focal offsets as Battle Prep and every other screen.
    var lv := leader.get_node_or_null("LeaderPortrait")
    if lv != null:
        lv.setup(faction_name, Vector2(200, 200))
    var name_label := leader.get_node_or_null("NameLabel") as Label
    if name_label != null:
        name_label.text = leader_name_for(faction_name)
        name_label.add_theme_color_override("font_color", class_accent_color(faction_name).lightened(0.28))
    _start_leader_class_aura(leader, faction_name)
    leader.tooltip_text = ("Your Leader: " if player_side else "Enemy Leader: ") + leader_name_for(faction_name)

func update_leaders() -> void:
    update_leader_visual(player_leader, selected_class, true)
    update_leader_visual(enemy_leader, enemy_class, false)

# Each leader has a short battle-start voice line, organized under
# assets/audio/voices/leaders/. Only your own leader speaks so lines never
# overlap or talk over each other.
func leader_voice_key(faction_name: String) -> String:
    match faction_name:
        "Hope": return "hope_lyra"
        "Courage": return "courage_kael"
        "Serenity": return "serenity_aurelia"
        "Purpose": return "purpose_orin"
        _: return ""

var leader_voice_played := false

func play_leader_voice() -> void:
    if leader_voice_played or not is_instance_valid(voice_player):
        return
    var key := leader_voice_key(selected_class)
    if key.is_empty():
        return
    var path := "res://assets/audio/voices/leaders/%s.wav" % key
    if not ResourceLoader.exists(path):
        return
    leader_voice_played = true
    voice_player.stream = load(path)
    voice_player.play()

func build_turn_timer() -> void:
    var timer_panel := Panel.new()
    timer_panel.position = Vector2(1042, 215)
    timer_panel.size = Vector2(218, 54)
    var timer_style := StyleBoxFlat.new()
    timer_style.bg_color = Color(0.025, 0.055, 0.085, 0.96)
    timer_style.border_color = Color(0.76, 0.88, 1.0)
    timer_style.set_border_width_all(2)
    timer_style.set_corner_radius_all(12)
    timer_panel.add_theme_stylebox_override("panel", timer_style)
    add_child(timer_panel)

    turn_timer_label = Label.new()
    turn_timer_label.position = Vector2(8, 2)
    turn_timer_label.size = Vector2(202, 20)
    turn_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    turn_timer_label.add_theme_font_size_override("font_size", ui_font(13))
    turn_timer_label.text = "TURN TIME  75"
    timer_panel.add_child(turn_timer_label)

    if practice_mode:
        var practice_badge := Label.new()
        practice_badge.position = Vector2(1042, 187)
        practice_badge.size = Vector2(218, 24)
        practice_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        practice_badge.add_theme_font_size_override("font_size", ui_font(13))
        practice_badge.add_theme_color_override("font_color", Color(0.55, 0.9, 0.6))
        practice_badge.text = "PRACTICE — NO REWARDS"
        add_child(practice_badge)

    turn_timer_bar = ProgressBar.new()
    turn_timer_bar.position = Vector2(10, 25)
    turn_timer_bar.size = Vector2(198, 18)
    turn_timer_bar.min_value = 0
    turn_timer_bar.max_value = PRACTICE_TURN_TIME_SECONDS if practice_mode else TURN_TIME_SECONDS
    turn_timer_bar.value = TURN_TIME_SECONDS
    turn_timer_bar.show_percentage = false
    timer_panel.add_child(turn_timer_bar)

func reset_turn_timer() -> void:
    turn_time_left = PRACTICE_TURN_TIME_SECONDS if practice_mode else TURN_TIME_SECONDS
    if is_instance_valid(turn_timer_bar):
        turn_timer_bar.max_value = turn_time_left
    slacking_warning_shown = false
    urgent_warning_shown = false
    player_turn_active = true
    if is_instance_valid(slacking_popup):
        slacking_popup.queue_free()
    update_turn_timer_ui()

func update_turn_timer_ui() -> void:
    if not is_instance_valid(turn_timer_bar) or not is_instance_valid(turn_timer_label):
        return
    turn_timer_bar.value = turn_time_left
    safe_set_text(turn_timer_label, "TURN TIME  %02d" % int(ceil(turn_time_left)))
    var fill := StyleBoxFlat.new()
    if turn_time_left <= URGENT_WARNING_SECONDS:
        fill.bg_color = Color(1.0, 0.18, 0.12)
        turn_timer_label.add_theme_color_override("font_color", Color(1.0, 0.46, 0.36))
    elif turn_time_left <= SLACKING_WARNING_SECONDS:
        fill.bg_color = Color(1.0, 0.72, 0.16)
        turn_timer_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.38))
    else:
        fill.bg_color = Color(0.22, 0.86, 0.48)
        turn_timer_label.add_theme_color_override("font_color", Color(0.78, 1.0, 0.88))
    fill.set_corner_radius_all(8)
    turn_timer_bar.add_theme_stylebox_override("fill", fill)

func show_slacking_animation(headline: String, subline: String, urgent: bool) -> void:
    if is_instance_valid(slacking_popup):
        slacking_popup.queue_free()
    slacking_popup = Panel.new()
    slacking_popup.position = Vector2(865, 390)
    slacking_popup.size = Vector2(205, 92)
    slacking_popup.z_index = 1500
    slacking_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.10, 0.035, 0.035, 0.97) if urgent else Color(0.05, 0.09, 0.12, 0.97)
    style.border_color = Color(1.0, 0.33, 0.22) if urgent else Color(1.0, 0.78, 0.28)
    style.set_border_width_all(3)
    style.set_corner_radius_all(15)
    style.shadow_color = Color(0, 0, 0, 0.75)
    style.shadow_size = 10
    slacking_popup.add_theme_stylebox_override("panel", style)
    add_child(slacking_popup)

    var icon := Label.new()
    icon.text = "Zzz" if not urgent else "!"
    icon.position = Vector2(8, 7)
    icon.size = Vector2(42, 72)
    icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    icon.add_theme_font_size_override("font_size", ui_font(27 if not urgent else 38))
    icon.add_theme_color_override("font_color", Color(0.78, 0.92, 1.0) if not urgent else Color(1.0, 0.35, 0.24))
    slacking_popup.add_child(icon)

    var headline_label := Label.new()
    headline_label.text = headline
    headline_label.position = Vector2(50, 12)
    headline_label.size = Vector2(146, 34)
    headline_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    headline_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    headline_label.add_theme_font_size_override("font_size", ui_font(13))
    headline_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
    slacking_popup.add_child(headline_label)

    var sub_label := Label.new()
    sub_label.text = subline
    sub_label.position = Vector2(50, 51)
    sub_label.size = Vector2(146, 25)
    sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    sub_label.add_theme_font_size_override("font_size", ui_font(12))
    sub_label.add_theme_color_override("font_color", Color(0.88, 0.93, 1.0))
    slacking_popup.add_child(sub_label)

    slacking_popup.scale = Vector2(0.55, 0.55)
    slacking_popup.modulate.a = 0.0
    var appear := create_tween().set_parallel(true)
    appear.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    appear.tween_property(slacking_popup, "scale", Vector2.ONE, 0.24)
    appear.tween_property(slacking_popup, "modulate:a", 1.0, 0.18)
    appear.tween_property(slacking_popup, "position:y", slacking_popup.position.y - 12.0, 0.24)
    await appear.finished
    var bob := create_tween().set_loops(3)
    bob.tween_property(slacking_popup, "position:y", slacking_popup.position.y - 5.0, 0.16)
    bob.tween_property(slacking_popup, "position:y", slacking_popup.position.y + 5.0, 0.16)
    await bob.finished
    await get_tree().create_timer(1.2 if urgent else 1.7).timeout
    if is_instance_valid(slacking_popup):
        var fade := create_tween()
        fade.tween_property(slacking_popup, "modulate:a", 0.0, 0.22)
        await fade.finished
        if is_instance_valid(slacking_popup):
            slacking_popup.queue_free()

func build_momentum_control() -> void:
    momentum_button = Button.new()
    momentum_button.position = Vector2(1015, 585)
    momentum_button.size = Vector2(205, 66)
    momentum_button.text = "MOMENTUM\n0 CHARGES"
    momentum_button.add_theme_font_size_override("font_size", ui_font(15))
    momentum_button.pressed.connect(activate_player_momentum)
    add_child(momentum_button)

    momentum_label = Label.new()
    momentum_label.position = Vector2(1005, 550)
    momentum_label.size = Vector2(225, 32)
    momentum_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    momentum_label.add_theme_font_size_override("font_size", ui_font(13))
    momentum_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.30))
    add_child(momentum_label)

# The Evolution Path — a rising staircase of four evolution "runes" instead
# of a flat row of identical buttons in a plain box. Each rune grows larger
# and shifts to a hotter color the higher its tier, so the escalating power
# curve (Ascend -> Ascend -> Awaken -> Transcend) is visible at a glance
# instead of only living in a tooltip. Available runes breathe with a slow
# glow pulse; spent ones go cold and grey.
const EVOLUTION_TIER_NAMES: Array[String] = ["ASCEND", "ASCEND", "AWAKEN", "TRANSCEND"]
const EVOLUTION_TIER_COLORS: Array[Color] = [
    Color(0.22, 0.5, 0.85),   # cool blue spark
    Color(0.16, 0.66, 0.62),  # teal surge
    Color(0.88, 0.64, 0.15),  # amber blaze
    Color(0.66, 0.2, 0.78),   # radiant transcendence
]
const EVOLUTION_TIER_GLOWS: Array[Color] = [
    Color(0.62, 0.85, 1.0),
    Color(0.55, 1.0, 0.92),
    Color(1.0, 0.88, 0.45),
    Color(1.0, 0.62, 1.0),
]
const EVOLUTION_TIER_SIZES: Array[int] = [34, 42, 50, 58]
const EVOLUTION_TIER_POS: Array[Vector2] = [
    Vector2(10, 96), Vector2(52, 84), Vector2(102, 72), Vector2(160, 60)
]

func build_evolution_panel() -> void:
    var panel := Panel.new()
    panel.position = Vector2(16, 546)
    panel.size = Vector2(236, 130)
    panel.z_index = 120
    var panel_style := StyleBoxFlat.new()
    panel_style.bg_color = Color(0.03, 0.045, 0.075, 0.92)
    panel_style.border_color = Color(1.0, 0.83, 0.4, 0.9)
    panel_style.set_border_width_all(2)
    # Asymmetric corners (sharp on one diagonal, rounded on the other) so the
    # backdrop reads as a banner/shard shape rather than a plain rectangle.
    panel_style.corner_radius_top_left = 6
    panel_style.corner_radius_top_right = 30
    panel_style.corner_radius_bottom_right = 6
    panel_style.corner_radius_bottom_left = 30
    panel_style.shadow_color = Color(0, 0, 0, 0.55)
    panel_style.shadow_size = 10
    panel.add_theme_stylebox_override("panel", panel_style)
    add_child(panel)

    # A slim amber ribbon across the top carries the title, breaking up the
    # box silhouette instead of just floating text on the same flat panel.
    var ribbon := Panel.new()
    ribbon.position = Vector2(6, 4)
    ribbon.size = Vector2(224, 13)
    var ribbon_style := StyleBoxFlat.new()
    ribbon_style.bg_color = Color(1.0, 0.83, 0.4, 0.95)
    ribbon_style.set_corner_radius_all(8)
    ribbon.add_theme_stylebox_override("panel", ribbon_style)
    panel.add_child(ribbon)

    var label := Label.new()
    label.text = "EVOLUTION PATH"
    label.position = Vector2(0, -1)
    label.size = Vector2(224, 14)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", ui_font(9))
    label.add_theme_color_override("font_color", Color(0.1, 0.08, 0.02))
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ribbon.add_child(label)

    var hint := Label.new()
    hint.text = "Drag a rune onto a follower"
    hint.position = Vector2(6, 18)
    hint.size = Vector2(224, 10)
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.add_theme_font_size_override("font_size", ui_font(7))
    hint.add_theme_color_override("font_color", Color(0.55, 0.65, 0.78))
    hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_child(hint)

    # A direct "abilities used" readout — the four runes below already show a
    # checkmark once spent, but that only reads clearly one at a time. This
    # gives a single at-a-glance count of how many evolutions are left.
    evolution_count_label = Label.new()
    evolution_count_label.position = Vector2(6, 28)
    evolution_count_label.size = Vector2(224, 12)
    evolution_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    evolution_count_label.add_theme_font_size_override("font_size", ui_font(10))
    evolution_count_label.add_theme_color_override("font_color", Color(1.0, 0.83, 0.35))
    evolution_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_child(evolution_count_label)

    evolution_buttons.clear()
    var star_counts: Array[int] = [1, 2, 3, 4]
    var tooltips: Array[String] = [
        "Ascend: +1 Attack",
        "Ascend: +1/+2",
        "Awaken: +3/+3",
        "Transcend: +4/+4 and activate its evolved ability"
    ]
    for i in range(4):
        var tier_size: int = EVOLUTION_TIER_SIZES[i]
        var orb := Button.new()
        orb.position = EVOLUTION_TIER_POS[i]
        orb.size = Vector2(tier_size, tier_size)
        orb.pivot_offset = Vector2(tier_size, tier_size) * 0.5
        orb.focus_mode = Control.FOCUS_NONE
        orb.text = "%s\n%d" % ["★".repeat(star_counts[i]), i + 1]
        orb.tooltip_text = "%d PP • %s: %s" % [i + 1, EVOLUTION_TIER_NAMES[i], tooltips[i]]
        orb.add_theme_font_size_override("font_size", ui_font(12 if tier_size >= 50 else 9))
        orb.add_theme_color_override("font_color", Color.WHITE)
        orb.add_theme_color_override("font_hover_color", Color.WHITE)
        var tier_color: Color = EVOLUTION_TIER_COLORS[i]
        var glow_color: Color = EVOLUTION_TIER_GLOWS[i]
        var normal := StyleBoxFlat.new()
        normal.bg_color = tier_color
        normal.border_color = glow_color
        normal.set_border_width_all(3)
        normal.set_corner_radius_all(tier_size)
        # A colored shadow doubles as a soft glow halo around the rune,
        # instead of every tier sharing one flat blue square.
        normal.shadow_color = Color(glow_color.r, glow_color.g, glow_color.b, 0.55)
        normal.shadow_size = 6 + i * 2
        orb.add_theme_stylebox_override("normal", normal)
        var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
        hover.bg_color = tier_color.lightened(0.22)
        hover.border_color = Color(1.0, 0.95, 0.6)
        hover.shadow_size = normal.shadow_size + 4
        orb.add_theme_stylebox_override("hover", hover)
        orb.add_theme_stylebox_override("pressed", hover)
        var evolution_cost: int = i + 1
        orb.gui_input.connect(func(event: InputEvent): _on_evolution_orb_input(event, evolution_cost, orb))
        orb.pressed.connect(func():
            if not orb.disabled:
                status_label.text = "Drag this %s rune (%d PP) onto an unevolved follower." % [EVOLUTION_TIER_NAMES[evolution_cost - 1], evolution_cost]
        )
        panel.add_child(orb)
        evolution_buttons.append(orb)

        # Tiny tier caption under each rune's own footprint (offset below the
        # button) so the staircase reads as named power tiers, not just
        # unlabeled colored circles.
        var tier_caption := Label.new()
        tier_caption.text = EVOLUTION_TIER_NAMES[i]
        tier_caption.position = orb.position + Vector2(-6, tier_size + 1)
        tier_caption.size = Vector2(tier_size + 12, 10)
        tier_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        tier_caption.add_theme_font_size_override("font_size", ui_font(6))
        tier_caption.add_theme_color_override("font_color", glow_color)
        tier_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
        panel.add_child(tier_caption)

        _start_evolution_orb_pulse(orb)

# Available runes slowly breathe (scale) so the panel feels like a live
# power source rather than a static row of buttons. Disabled/used runes are
# also dimmed per-frame in refresh_ui via modulate, so the pulse checks
# `disabled` on every step and snaps back to rest scale instead of animating.
func _start_evolution_orb_pulse(orb: Button) -> void:
    var pulse := create_tween().set_loops().bind_node(orb)
    pulse.tween_method(_apply_evolution_pulse.bind(orb), 0.0, 1.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    pulse.tween_method(_apply_evolution_pulse.bind(orb), 1.0, 0.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _apply_evolution_pulse(t: float, orb: Button) -> void:
    if not is_instance_valid(orb):
        return
    if orb.disabled:
        orb.scale = Vector2.ONE
        return
    var s := 1.0 + 0.08 * t
    orb.scale = Vector2(s, s)

func _on_evolution_orb_input(event: InputEvent, cost: int, orb: Button) -> void:
    if orb.disabled or game_over or busy or not player_turn_active:
        return
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        evolution_drag_cost = cost
        evolution_drag_start = get_viewport().get_mouse_position()
        evolution_dragging = false
        evolution_drag_orb = orb
        orb.accept_event()
    elif event is InputEventScreenTouch and event.pressed:
        evolution_drag_cost = cost
        evolution_drag_start = event.position
        evolution_dragging = false
        evolution_drag_orb = orb
        orb.accept_event()

func _input(event: InputEvent) -> void:
    if evolution_drag_cost <= 0 or not is_instance_valid(evolution_drag_orb):
        return

    var current_position := Vector2.ZERO
    var released := false

    if event is InputEventScreenDrag:
        current_position = event.position
    elif event is InputEventScreenTouch:
        current_position = event.position
        released = not event.pressed
    elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
        current_position = get_viewport().get_mouse_position()
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        current_position = get_viewport().get_mouse_position()
        released = not event.pressed
    else:
        return

    if not released and current_position.distance_to(evolution_drag_start) >= EVOLUTION_DRAG_THRESHOLD:
        evolution_dragging = true
        evolution_drag_orb.pivot_offset = evolution_drag_orb.size * 0.5
        evolution_drag_orb.scale = Vector2(1.12, 1.12)
        evolution_drag_orb.modulate = Color(1.25, 1.15, 0.62)
        status_label.text = "Drop the evolution orb onto the follower you want to evolve."
        get_viewport().set_input_as_handled()
        return

    if released:
        var orb := evolution_drag_orb
        var cost := evolution_drag_cost
        var was_dragging := evolution_dragging
        evolution_drag_cost = 0
        evolution_dragging = false
        evolution_drag_orb = null
        if is_instance_valid(orb):
            orb.modulate = Color.WHITE
            orb.scale = Vector2.ONE
            orb.pivot_offset = orb.size * 0.5
        if was_dragging:
            suppress_orb_click(orb)
            _finish_evolution_drag(cost, current_position)
            get_viewport().set_input_as_handled()

func suppress_orb_click(orb: Button) -> void:
    orb.set_meta("drag_release", true)
    get_tree().create_timer(0.12).timeout.connect(func():
        if is_instance_valid(orb):
            orb.set_meta("drag_release", false)
    )

func _finish_evolution_drag(cost: int, release_global: Vector2) -> void:
    if game_over or busy or not player_turn_active:
        return
    if turn_number < 4:
        status_label.text = "Evolution is not available until Turn 4."
        return
    if cost < 1 or cost > 4 or player_evolutions_used[cost - 1]:
        return
    if player_mana < cost:
        status_label.text = "You need %d Play Points for that evolution." % cost
        return
    for child in player_board_area.get_children():
        if child is CardView and child.get_global_rect().grow(28.0).has_point(release_global):
            var index: int = child.card_index
            if index < 0 or index >= player_board.size():
                continue
            if bool(player_board[index].get("is_amulet", false)):
                status_label.text = "Recovery Skills cannot evolve."
                return
            if bool(player_board[index].get("evolved", false)):
                status_label.text = "%s has already evolved." % str(player_board[index].get("name", "That follower"))
                return
            busy = true
            await evolve_follower(index, cost, true)
            busy = false
            refresh_ui()
            return
    status_label.text = "Drop the evolution orb directly onto an unevolved follower."

func choose_evolution(cost: int) -> void:
    if game_over or busy:
        return
    if turn_number < 4:
        status_label.text = "Evolution is not available until Turn 4."
        return
    var used_index: int = cost - 1
    if used_index < 0 or used_index >= player_evolutions_used.size() or player_evolutions_used[used_index]:
        return
    if player_mana < cost:
        status_label.text = "You need %d play points to use this Evolution card." % cost
        return
    if player_board.is_empty():
        status_label.text = "You need a follower on the field to evolve."
        return
    selected_attacker = -1
    selected_evolution_cost = cost
    status_label.text = "Choose one of your unevolved followers."
    refresh_ui()

func evolve_follower(index: int, cost: int, player_side: bool) -> void:
    var board: Array = player_board if player_side else enemy_board
    if index < 0 or index >= board.size():
        return
    var follower: Dictionary = board[index]
    if bool(follower.get("evolved", false)):
        if player_side:
            status_label.text = "%s has already evolved." % str(follower.get("name", "Follower"))
        return

    if player_side:
        if player_mana < cost:
            return
        player_mana -= cost
        player_evolutions_used[cost - 1] = true
    else:
        if enemy_mana < cost:
            return
        enemy_mana -= cost
        enemy_evolutions_used[cost - 1] = true

    var attack_gain: int = 1 if cost < 3 else (3 if cost == 3 else 4)
    var defense_gain: int = 0 if cost == 1 else (2 if cost == 2 else (3 if cost == 3 else 4))
    # Commit gameplay state before the cinematic. A missing/timed-out visual can
    # never prevent the evolved follower from attacking enemy followers.
    follower["attack"] = int(follower.get("attack", 0)) + attack_gain
    follower["health"] = int(follower.get("health", 0)) + defense_gain
    follower["max_health"] = int(follower.get("max_health", follower.get("health", 0))) + defense_gain
    follower["evolved"] = true
    follower["can_attack"] = true
    follower["evolved_this_turn"] = true
    board[index] = follower

    await play_evolution_animation(index, cost, player_side)
    if str(follower.get("faction", "")) == "Purpose":
        if player_side:
            player_purpose_evolves += 1
            if player_purpose_evolves == 3:
                await trigger_finding_purpose_milestone(true)
        else:
            enemy_purpose_evolves += 1
            if enemy_purpose_evolves == 3:
                await trigger_finding_purpose_milestone(false)

    var area: Control = player_board_area if player_side else enemy_board_area
    await show_vfx("EVOLVED +%d/+%d" % [attack_gain, defense_gain], area.global_position + Vector2(270 + index * 55, 55), Color(0.72, 0.92, 1.0))
    if str(follower.get("ability", "")) == "rise_together":
        await resolve_rise_together_evolution(player_side)
    elif cost >= 3:
        await resolve_awakened_ability(follower, player_side)
    selected_evolution_cost = 0
    refresh_ui()


func free_evolve_rise_together(index: int, player_side: bool) -> void:
    var board: Array = player_board if player_side else enemy_board
    if index < 0 or index >= board.size():
        return
    var follower: Dictionary = board[index]
    if bool(follower.get("evolved", false)):
        return
    follower["attack"] = int(follower.get("attack", 0)) + 2
    follower["health"] = int(follower.get("health", 0)) + 2
    follower["max_health"] = int(follower.get("max_health", follower.get("health", 0))) + 2
    follower["evolved"] = true
    follower["can_attack"] = true
    follower["evolved_this_turn"] = true
    board[index] = follower
    await play_evolution_animation(index, 3, player_side)
    await show_vfx("FREE EVOLVE +2/+2", area_center(player_side), Color(1.0, 0.72, 0.22))
    await resolve_rise_together_evolution(player_side)

func resolve_rise_together_evolution(player_side: bool) -> void:
    var deck: Array = player_deck if player_side else enemy_deck
    var buffed := 0
    for deck_card in deck:
        if str(deck_card.get("faction", "")) != "Courage":
            continue
        deck_card["attack"] = int(deck_card.get("attack", 0)) + 1
        deck_card["health"] = int(deck_card.get("health", 0)) + 1
        deck_card["max_health"] = int(deck_card.get("max_health", deck_card.get("health", 0))) + 1
        deck_card["rise_together_buffed"] = true
        buffed += 1
    await show_vfx("RISE TOGETHER: %d CARDS +1/+1" % buffed, area_center(player_side), Color(1.0, 0.84, 0.28))
    safe_set_text(status_label, "Rise Together empowered every Courage follower remaining in the deck.")

func has_evolved_rise_together(board: Array) -> bool:
    for ally in board:
        if str(ally.get("ability", "")) == "rise_together" and bool(ally.get("evolved", false)):
            return true
    return false

func find_card_view_for_board_index(area: Control, board_index: int) -> CardView:
    if not is_instance_valid(area):
        return null
    for child in area.get_children():
        if child is CardView and child.card_index == board_index:
            return child as CardView
    return null

# Dispatcher: routes to a tier-appropriate cinematic based on the evolving
# follower's rarity. Bronze/Silver/Gold/Token/Training keep the original,
# efficient animation — Epic/Legendary/Platinum get a progressively bigger
# show built around the card's own real artwork instead of procedural shapes.
func play_evolution_animation(index: int, cost: int, player_side: bool) -> void:
    var board: Array = player_board if player_side else enemy_board
    var rarity := "Bronze"
    if index >= 0 and index < board.size():
        rarity = str(board[index].get("rarity", "Bronze"))
    match rarity:
        "Platinum":
            await play_platinum_evolution_animation(index, cost, player_side)
        "Legendary":
            await play_legendary_evolution_animation(index, cost, player_side)
        "Epic":
            await play_epic_evolution_animation(index, cost, player_side)
        _:
            await play_standard_evolution_animation(index, cost, player_side)

func play_standard_evolution_animation(index: int, cost: int, player_side: bool) -> void:
    var area: Control = player_board_area if player_side else enemy_board_area
    if index < 0:
        return
    var card_view: CardView = find_card_view_for_board_index(area, index)
    if card_view == null:
        return
    var board_std: Array = player_board if player_side else enemy_board
    var follower_std: Dictionary = board_std[index]

    busy = true
    play_sfx("evolve_cinematic")
    card_view.z_index = 1200
    var original_position: Vector2 = card_view.position
    var original_scale: Vector2 = card_view.scale
    var screen_center: Vector2 = Vector2(640.0, 360.0)
    var centered_position: Vector2 = screen_center - card_view.size * 0.5 - area.global_position

    var evo_col := Color(0.28, 0.82, 1.0) if cost < 3 else (Color(0.95, 0.72, 0.20) if cost == 3 else Color(0.85, 0.42, 1.0))

    # Full-bleed backdrop of the card's own art — cinematic even at standard tier
    var backdrop := TextureRect.new()
    backdrop.texture = CardArt.resolve(follower_std)
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
    backdrop.modulate = Color(1.0, 1.0, 1.0, 0.0)
    backdrop.z_index = 1085
    add_child(backdrop)

    var dimmer := ColorRect.new()
    dimmer.color = Color(0.01, 0.02, 0.05, 0.0)
    dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    dimmer.z_index = 1095
    add_child(dimmer)

    # Title — starts huge, smashes down to reading size
    var title := Label.new()
    title.text = "ASCEND" if cost < 3 else ("AWAKEN" if cost == 3 else "TRANSCEND")
    title.position = Vector2(390, 90)
    title.size = Vector2(500, 70)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", ui_font(46 if cost < 3 else (54 if cost == 3 else 48)))
    title.add_theme_color_override("font_color", evo_col)
    title.add_theme_color_override("font_shadow_color", Color.BLACK)
    title.add_theme_constant_override("shadow_offset_x", 5)
    title.add_theme_constant_override("shadow_offset_y", 5)
    title.pivot_offset = Vector2(250, 35)
    title.scale = Vector2(2.8, 2.8)
    title.modulate.a = 0.0
    title.z_index = 1300
    add_child(title)

    # Phase 1 — backdrop + dimmer fade in, card slides to centre
    var rise := create_tween().set_parallel(true)
    rise.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    rise.tween_property(dimmer,   "color:a",              0.82,             0.22)
    rise.tween_property(backdrop, "modulate:a",           0.22,             0.30)
    rise.tween_property(card_view, "position",            centered_position, 0.34)
    rise.tween_property(card_view, "scale",    Vector2(1.80, 1.80),         0.34)
    await rise.finished

    # Phase 2 — white flash, title smash-in, three staggered expanding rings
    var flash := ColorRect.new()
    flash.color = Color(1.0, 1.0, 1.0, 0.0)
    flash.z_index = 1450
    flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
    flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(flash)
    var ft := create_tween()
    ft.tween_property(flash, "color:a", 0.90, 0.07)
    ft.tween_property(flash, "color:a", 0.0,  0.22)
    ft.finished.connect(flash.queue_free)

    for ri in range(3):
        var rsz := float(180 + ri * 90)
        var er := ColorRect.new()
        er.size = Vector2(rsz, rsz)
        er.color = Color(evo_col.r, evo_col.g, evo_col.b, 0.55 - ri * 0.12)
        er.position = screen_center - Vector2(rsz * 0.5, rsz * 0.5)
        er.mouse_filter = Control.MOUSE_FILTER_IGNORE
        er.z_index = 1150
        add_child(er)
        var rt := create_tween().set_parallel(true)
        rt.tween_property(er, "scale",     Vector2(2.2, 2.2), 0.42).set_delay(ri * 0.07)
        rt.tween_property(er, "color:a",   0.0,               0.36).set_delay(ri * 0.07)
        rt.finished.connect(er.queue_free)

    # Title smashes in
    var tt := create_tween().set_parallel(true)
    tt.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tt.tween_property(title, "scale",      Vector2(1.0, 1.0), 0.24)
    tt.tween_property(title, "modulate:a", 1.0,               0.18)
    await tt.finished

    # Card pulses three times
    var pulse := create_tween().set_loops(3)
    pulse.tween_property(card_view, "scale", Vector2(2.0, 2.0), 0.09)
    pulse.tween_property(card_view, "scale", Vector2(1.80, 1.80), 0.07)
    await pulse.finished

    spawn_sparkle_burst(screen_center, 18 if CardView.graphics_quality >= 1 else 6,
        [evo_col, Color.WHITE, evo_col.lightened(0.4)], self, 95.0)
    _spawn_impact_ring(screen_center, evo_col, mini(cost + 2, 5))

    var stat_text := Label.new()
    stat_text.text = "+1 ATK" if cost == 1 else ("+1 ATK  +2 DEF" if cost == 2 else ("+3 ATK  +3 DEF\nSPECIAL ABILITY" if cost == 3 else "+4 ATK  +4 DEF\nSPECIAL ABILITY"))
    stat_text.position = Vector2(390, 565)
    stat_text.size = Vector2(500, 80)
    stat_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    stat_text.add_theme_font_size_override("font_size", ui_font(30 if cost < 3 else 34))
    stat_text.add_theme_color_override("font_color", evo_col.lightened(0.3))
    stat_text.add_theme_color_override("font_shadow_color", Color.BLACK)
    stat_text.add_theme_constant_override("shadow_offset_x", 3)
    stat_text.add_theme_constant_override("shadow_offset_y", 3)
    stat_text.modulate.a = 0.0
    stat_text.z_index = 1300
    add_child(stat_text)

    var reveal := create_tween()
    reveal.tween_property(stat_text, "modulate:a", 1.0, 0.18)
    await reveal.finished
    await get_tree().create_timer(0.28).timeout

    var return_tween := create_tween().set_parallel(true)
    return_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
    return_tween.tween_property(card_view, "position",   original_position, 0.26)
    return_tween.tween_property(card_view, "scale",      original_scale,    0.26)
    return_tween.tween_property(dimmer,    "color:a",    0.0,               0.22)
    return_tween.tween_property(backdrop,  "modulate:a", 0.0,               0.20)
    return_tween.tween_property(title,     "modulate:a", 0.0,               0.18)
    return_tween.tween_property(stat_text, "modulate:a", 0.0,               0.18)
    await return_tween.finished

    card_view.z_index = 0
    for n in [dimmer, backdrop, title, stat_text]:
        if is_instance_valid(n): n.queue_free()
    busy = false

func play_epic_evolution_animation(index: int, cost: int, player_side: bool) -> void:
    var area: Control = player_board_area if player_side else enemy_board_area
    if index < 0:
        return
    var card_view: CardView = find_card_view_for_board_index(area, index)
    if card_view == null:
        return
    var board: Array = player_board if player_side else enemy_board
    var follower: Dictionary = board[index]

    busy = true
    play_sfx("evolve_cinematic")
    card_view.z_index = 1200
    var original_position: Vector2 = card_view.position
    var original_scale: Vector2 = card_view.scale
    var screen_center := Vector2(640.0, 360.0)
    var centered_position: Vector2 = screen_center - card_view.size * 0.5 - area.global_position

    # Full-bleed backdrop — card art fills the screen, tinted purple, semi-transparent
    var backdrop := TextureRect.new()
    backdrop.texture = CardArt.resolve(follower)
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
    backdrop.modulate = Color(0.72, 0.45, 1.0, 0.0)
    backdrop.z_index = 1082
    add_child(backdrop)

    var dimmer := ColorRect.new()
    dimmer.color = Color(0.02, 0.01, 0.06, 0.0)
    dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    dimmer.z_index = 1092
    add_child(dimmer)

    # Spinning beam crown behind the card
    var beam_root := Control.new()
    beam_root.position = screen_center
    beam_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    beam_root.z_index = 1115
    beam_root.modulate.a = 0.0
    add_child(beam_root)
    for i in range(12):
        var beam := ColorRect.new()
        beam.color = Color(0.80, 0.42, 1.0, 0.60)
        beam.size = Vector2(4, 220)
        beam.position = Vector2(-2, -110)
        beam.pivot_offset = Vector2(2, 110)
        beam.rotation = TAU * float(i) / 12.0
        beam.mouse_filter = Control.MOUSE_FILTER_IGNORE
        beam_root.add_child(beam)
    var spin := create_tween().set_loops().bind_node(beam_root)
    spin.tween_property(beam_root, "rotation", TAU, 5.0).set_trans(Tween.TRANS_LINEAR)

    # Large art medallion on the right — starts off-screen, slides in
    var medallion := build_art_medallion(CardArt.resolve(follower),
        screen_center + Vector2(340, -60), Vector2(200, 280), Color(0.82, 0.48, 1.0), 18)
    medallion.modulate.a = 0.0
    medallion.scale = Vector2(0.5, 0.5)
    add_child(medallion)

    var title := Label.new()
    title.text = "EPIC EVOLUTION"
    title.position = Vector2(290, 82)
    title.size = Vector2(700, 70)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", ui_font(52))
    title.add_theme_color_override("font_color", Color(0.90, 0.65, 1.0))
    title.add_theme_color_override("font_shadow_color", Color(0.3, 0.0, 0.6, 0.9))
    title.add_theme_constant_override("shadow_offset_x", 5)
    title.add_theme_constant_override("shadow_offset_y", 5)
    title.pivot_offset = Vector2(350, 35)
    title.scale = Vector2(2.5, 2.5)
    title.modulate.a = 0.0
    title.z_index = 1300
    add_child(title)

    # Phase 1 — everything rises simultaneously
    var rise := create_tween().set_parallel(true)
    rise.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    rise.tween_property(dimmer,    "color:a",              0.86,            0.22)
    rise.tween_property(backdrop,  "modulate:a",           0.28,            0.35)
    rise.tween_property(beam_root, "modulate:a",           0.80,            0.40)
    rise.tween_property(card_view, "position",             centered_position, 0.36)
    rise.tween_property(card_view, "scale",    Vector2(1.85, 1.85),         0.36)
    rise.tween_property(medallion, "position", screen_center + Vector2(150, -60), 0.40).set_delay(0.10)
    rise.tween_property(medallion, "modulate:a", 1.0,                       0.32).set_delay(0.10)
    rise.tween_property(medallion, "scale",    Vector2(1.0, 1.0),           0.32).set_delay(0.10)
    await rise.finished

    # Phase 2 — flash, title smash, staggered rings
    var flash := ColorRect.new()
    flash.color = Color(0.85, 0.60, 1.0, 0.0)
    flash.z_index = 1450
    flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
    flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(flash)
    var ft := create_tween()
    ft.tween_property(flash, "color:a", 0.80, 0.07)
    ft.tween_property(flash, "color:a", 0.0,  0.22)
    ft.finished.connect(flash.queue_free)

    for ri in range(4):
        var rsz := float(160 + ri * 80)
        var er := ColorRect.new()
        er.size = Vector2(rsz, rsz)
        er.color = Color(0.78, 0.38, 1.0, 0.60 - ri * 0.10)
        er.position = screen_center - Vector2(rsz * 0.5, rsz * 0.5)
        er.mouse_filter = Control.MOUSE_FILTER_IGNORE
        er.z_index = 1150
        add_child(er)
        var rt := create_tween().set_parallel(true)
        rt.tween_property(er, "scale",   Vector2(2.4, 2.4), 0.48).set_delay(ri * 0.06)
        rt.tween_property(er, "color:a", 0.0,               0.40).set_delay(ri * 0.06)
        rt.finished.connect(er.queue_free)

    var tt := create_tween().set_parallel(true)
    tt.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tt.tween_property(title, "scale",      Vector2(1.0, 1.0), 0.26)
    tt.tween_property(title, "modulate:a", 1.0,               0.20)
    await tt.finished

    var pulse := create_tween().set_loops(3)
    pulse.tween_property(card_view, "scale", Vector2(2.05, 2.05), 0.09)
    pulse.tween_property(card_view, "scale", Vector2(1.85, 1.85), 0.08)
    await pulse.finished

    spawn_sparkle_burst(screen_center, 22 if CardView.graphics_quality >= 1 else 8,
        [Color(0.90, 0.65, 1.0), Color(1.0, 1.0, 1.0), Color(0.62, 0.82, 1.0)], self, 105.0)
    _spawn_impact_ring(screen_center, Color(0.82, 0.48, 1.0), 5)

    var attack_gain: int = 1 if cost < 3 else (3 if cost == 3 else 4)
    var defense_gain: int = 0 if cost == 1 else (2 if cost == 2 else (3 if cost == 3 else 4))
    var stat_text := Label.new()
    stat_text.text = "+%d ATK  +%d DEF" % [attack_gain, defense_gain]
    stat_text.position = Vector2(290, 570)
    stat_text.size = Vector2(700, 68)
    stat_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    stat_text.add_theme_font_size_override("font_size", ui_font(34))
    stat_text.add_theme_color_override("font_color", Color(0.92, 0.75, 1.0))
    stat_text.add_theme_color_override("font_shadow_color", Color(0.3, 0.0, 0.6, 0.9))
    stat_text.add_theme_constant_override("shadow_offset_x", 3)
    stat_text.add_theme_constant_override("shadow_offset_y", 3)
    stat_text.modulate.a = 0.0
    stat_text.z_index = 1300
    add_child(stat_text)

    var reveal := create_tween()
    reveal.tween_property(stat_text, "modulate:a", 1.0, 0.18)
    await reveal.finished
    await get_tree().create_timer(0.30).timeout

    spin.kill()
    var return_tween := create_tween().set_parallel(true)
    return_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
    return_tween.tween_property(card_view, "position",   original_position, 0.28)
    return_tween.tween_property(card_view, "scale",      original_scale,    0.28)
    return_tween.tween_property(dimmer,    "color:a",    0.0,               0.24)
    return_tween.tween_property(backdrop,  "modulate:a", 0.0,               0.22)
    return_tween.tween_property(beam_root, "modulate:a", 0.0,               0.22)
    return_tween.tween_property(medallion, "modulate:a", 0.0,               0.22)
    return_tween.tween_property(title,     "modulate:a", 0.0,               0.20)
    return_tween.tween_property(stat_text, "modulate:a", 0.0,               0.20)
    await return_tween.finished

    card_view.z_index = 0
    for n in [dimmer, backdrop, beam_root, medallion, title, stat_text]:
        if is_instance_valid(n): n.queue_free()
    busy = false

func play_legendary_evolution_animation(index: int, cost: int, player_side: bool) -> void:
    var area: Control = player_board_area if player_side else enemy_board_area
    if index < 0:
        return
    var card_view: CardView = find_card_view_for_board_index(area, index)
    if card_view == null:
        return
    var board: Array = player_board if player_side else enemy_board
    var follower: Dictionary = board[index]

    busy = true
    play_sfx("evolve_cinematic")
    card_view.z_index = 1200
    var original_position: Vector2 = card_view.position
    var original_scale: Vector2 = card_view.scale
    var screen_center := Vector2(640.0, 360.0)
    var centered_position: Vector2 = screen_center - card_view.size * 0.5 - area.global_position

    var dimmer := ColorRect.new()
    dimmer.color = Color(0.01, 0.015, 0.03, 0.0)
    dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    dimmer.z_index = 1100
    add_child(dimmer)

    # A slowly spinning ring of gold light beams behind the card — the
    # "legendary aura" that separates this tier from the standard ring flash.
    var beam_root := Control.new()
    beam_root.position = screen_center
    beam_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    beam_root.z_index = 1120
    beam_root.modulate.a = 0.0
    add_child(beam_root)
    for i in range(8):
        var beam := ColorRect.new()
        beam.color = Color(1.0, 0.84, 0.32, 0.55)
        beam.size = Vector2(6, 260)
        beam.position = Vector2(-3, -130)
        beam.pivot_offset = Vector2(3, 130)
        beam.rotation = TAU * float(i) / 8.0
        beam.mouse_filter = Control.MOUSE_FILTER_IGNORE
        beam_root.add_child(beam)
    var spin := create_tween().set_loops().bind_node(beam_root)
    spin.tween_property(beam_root, "rotation", TAU, 6.0).set_trans(Tween.TRANS_LINEAR)

    var hero_portrait := build_art_medallion(CardArt.resolve(follower), screen_center - Vector2(150, 230), Vector2(300, 380), Color(1.0, 0.84, 0.30), 22)
    hero_portrait.scale = Vector2(0.5, 0.5)
    hero_portrait.z_index = 1130
    add_child(hero_portrait)

    var ring := ColorRect.new()
    ring.position = screen_center - Vector2(120, 120)
    ring.size = Vector2(240, 240)
    ring.color = Color(1.0, 0.84, 0.28, 0.0)
    ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ring.z_index = 1150
    add_child(ring)

    var title := Label.new()
    title.text = "LEGENDARY AWAKENING"
    title.position = Vector2(240, 78)
    title.size = Vector2(800, 74)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", ui_font(52))
    title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.34))
    title.add_theme_color_override("font_shadow_color", Color.BLACK)
    title.add_theme_constant_override("shadow_offset_x", 4)
    title.add_theme_constant_override("shadow_offset_y", 4)
    title.modulate.a = 0.0
    title.z_index = 1300
    add_child(title)

    var rise := create_tween().set_parallel(true)
    rise.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    rise.tween_property(dimmer, "color:a", 0.88, 0.24)
    rise.tween_property(beam_root, "modulate:a", 0.9, 0.5)
    rise.tween_property(hero_portrait, "modulate:a", 1.0, 0.4)
    rise.tween_property(hero_portrait, "scale", Vector2(1.0, 1.0), 0.4)
    rise.tween_property(card_view, "position", centered_position + Vector2(70, 0), 0.4)
    rise.tween_property(card_view, "scale", Vector2(1.9, 1.9), 0.4)
    rise.tween_property(title, "modulate:a", 1.0, 0.26)
    rise.tween_property(ring, "color:a", 0.26, 0.3)
    await rise.finished

    await get_tree().create_timer(0.15).timeout
    var pulse := create_tween().set_loops(3)
    pulse.tween_property(card_view, "scale", Vector2(2.05, 2.05), 0.11)
    pulse.tween_property(card_view, "scale", Vector2(1.9, 1.9), 0.11)
    await pulse.finished
    spawn_sparkle_burst(screen_center, 24, [Color(1.0, 0.86, 0.34), Color(1.0, 1.0, 1.0), Color(1.0, 0.66, 0.22)], self, 115.0)
    _spawn_impact_ring(screen_center, Color(1.0, 0.72, 0.18), 5)

    var attack_gain: int = 1 if cost < 3 else (3 if cost == 3 else 4)
    var defense_gain: int = 0 if cost == 1 else (2 if cost == 2 else (3 if cost == 3 else 4))
    var stat_text := Label.new()
    stat_text.text = "+%d ATK  +%d DEF\nSPECIAL ABILITY" % [attack_gain, defense_gain]
    stat_text.position = Vector2(240, 578)
    stat_text.size = Vector2(800, 84)
    stat_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    stat_text.add_theme_font_size_override("font_size", ui_font(36))
    stat_text.add_theme_color_override("font_color", Color(1.0, 0.90, 0.42))
    stat_text.add_theme_color_override("font_shadow_color", Color.BLACK)
    stat_text.add_theme_constant_override("shadow_offset_x", 3)
    stat_text.add_theme_constant_override("shadow_offset_y", 3)
    stat_text.modulate.a = 0.0
    stat_text.z_index = 1300
    add_child(stat_text)

    var reveal := create_tween().set_parallel(true)
    reveal.tween_property(stat_text, "modulate:a", 1.0, 0.2)
    reveal.tween_property(ring, "scale", Vector2(1.45, 1.45), 0.34)
    reveal.tween_property(ring, "color:a", 0.0, 0.34)
    await reveal.finished
    await get_tree().create_timer(0.3).timeout

    spin.kill()
    var return_tween := create_tween().set_parallel(true)
    return_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
    return_tween.tween_property(card_view, "position", original_position, 0.3)
    return_tween.tween_property(card_view, "scale", original_scale, 0.3)
    return_tween.tween_property(dimmer, "color:a", 0.0, 0.26)
    return_tween.tween_property(beam_root, "modulate:a", 0.0, 0.22)
    return_tween.tween_property(hero_portrait, "modulate:a", 0.0, 0.22)
    return_tween.tween_property(title, "modulate:a", 0.0, 0.2)
    return_tween.tween_property(stat_text, "modulate:a", 0.0, 0.2)
    await return_tween.finished

    card_view.z_index = 0
    dimmer.queue_free()
    beam_root.queue_free()
    hero_portrait.queue_free()
    ring.queue_free()
    title.queue_free()
    stat_text.queue_free()
    busy = false

func play_platinum_evolution_animation(index: int, cost: int, player_side: bool) -> void:
    var area: Control = player_board_area if player_side else enemy_board_area
    if index < 0:
        return
    var card_view: CardView = find_card_view_for_board_index(area, index)
    if card_view == null:
        return
    var board: Array = player_board if player_side else enemy_board
    var follower: Dictionary = board[index]

    busy = true
    var old_music_db := music_player.volume_db if is_instance_valid(music_player) else -5.0
    if is_instance_valid(music_player):
        var duck := create_tween()
        duck.tween_property(music_player, "volume_db", old_music_db - 10.0, 0.3)
    play_sfx("evolve_cinematic")
    card_view.z_index = 1200
    var original_position: Vector2 = card_view.position
    var original_scale: Vector2 = card_view.scale
    var screen_center := Vector2(640.0, 360.0)
    var centered_position: Vector2 = screen_center - card_view.size * 0.5 - area.global_position

    var dimmer := ColorRect.new()
    dimmer.color = Color(0.0, 0.0, 0.0, 0.0)
    dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    dimmer.z_index = 1100
    add_child(dimmer)

    # Full-bleed backdrop art behind everything, softened by the dimmer above
    # it, so the reveal feels like the follower's own portrait taking over the
    # whole screen rather than a small procedural flash.
    var backdrop_art := TextureRect.new()
    backdrop_art.texture = CardArt.resolve(follower)
    backdrop_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    backdrop_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    backdrop_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    backdrop_art.clip_contents = true
    backdrop_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
    backdrop_art.modulate = Color(1, 1, 1, 0.0)
    backdrop_art.z_index = 1090
    add_child(backdrop_art)

    var beam_root := Control.new()
    beam_root.position = screen_center
    beam_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    beam_root.z_index = 1120
    beam_root.modulate.a = 0.0
    add_child(beam_root)
    for i in range(10):
        var beam := ColorRect.new()
        beam.color = Color(1.0, 0.95, 0.75, 0.5)
        beam.size = Vector2(7, 340)
        beam.position = Vector2(-3.5, -170)
        beam.pivot_offset = Vector2(3.5, 170)
        beam.rotation = TAU * float(i) / 10.0
        beam.mouse_filter = Control.MOUSE_FILTER_IGNORE
        beam_root.add_child(beam)
    var spin := create_tween().set_loops().bind_node(beam_root)
    spin.tween_property(beam_root, "rotation", TAU, 8.0).set_trans(Tween.TRANS_LINEAR)

    var ring_outer := ColorRect.new()
    ring_outer.position = screen_center - Vector2(160, 160)
    ring_outer.size = Vector2(320, 320)
    ring_outer.color = Color(0.95, 0.90, 0.75, 0.0)
    ring_outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ring_outer.z_index = 1140
    add_child(ring_outer)

    var ring_inner := ColorRect.new()
    ring_inner.position = screen_center - Vector2(110, 110)
    ring_inner.size = Vector2(220, 220)
    ring_inner.color = Color(1.0, 0.84, 0.30, 0.0)
    ring_inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ring_inner.z_index = 1150
    add_child(ring_inner)

    # Cheap "chromatic sheen" title: the same text drawn twice, one copy offset
    # a couple pixels and tinted, so premium text reads richer than a single
    # flat-colored label without needing a shader.
    var title_shadow_layer := Label.new()
    title_shadow_layer.text = "PLATINUM ASCENSION"
    title_shadow_layer.position = Vector2(158, 66)
    title_shadow_layer.size = Vector2(970, 84)
    title_shadow_layer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title_shadow_layer.add_theme_font_size_override("font_size", ui_font(58))
    title_shadow_layer.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0, 0.0))
    title_shadow_layer.z_index = 1295
    title_shadow_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(title_shadow_layer)

    var title := Label.new()
    title.text = "PLATINUM ASCENSION"
    title.position = Vector2(160, 64)
    title.size = Vector2(970, 84)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", ui_font(58))
    title.add_theme_color_override("font_color", Color(1.0, 0.96, 0.85, 0.0))
    title.add_theme_color_override("font_shadow_color", Color.BLACK)
    title.add_theme_constant_override("shadow_offset_x", 4)
    title.add_theme_constant_override("shadow_offset_y", 4)
    title.z_index = 1300
    title.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(title)

    var rise := create_tween().set_parallel(true)
    rise.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    rise.tween_property(dimmer, "color:a", 0.80, 0.4)
    rise.tween_property(backdrop_art, "modulate:a", 0.30, 0.6)
    rise.tween_property(beam_root, "modulate:a", 1.0, 0.6)
    rise.tween_property(card_view, "position", centered_position, 0.5)
    rise.tween_property(card_view, "scale", Vector2(2.0, 2.0), 0.5)
    rise.tween_property(title, "theme_override_colors/font_color:a", 1.0, 0.34)
    rise.tween_property(title_shadow_layer, "theme_override_colors/font_color:a", 0.5, 0.34)
    rise.tween_property(ring_outer, "color:a", 0.20, 0.4)
    rise.tween_property(ring_inner, "color:a", 0.30, 0.4)
    await rise.finished

    var sheen := create_tween().set_parallel(true)
    sheen.tween_property(title_shadow_layer, "position:x", title_shadow_layer.position.x - 3, 0.5)
    sheen.tween_property(title_shadow_layer, "position:x", title_shadow_layer.position.x + 3, 0.5).set_delay(0.5)

    await get_tree().create_timer(0.18).timeout
    var pulse := create_tween().set_loops(3)
    pulse.tween_property(card_view, "scale", Vector2(2.18, 2.18), 0.12)
    pulse.tween_property(card_view, "scale", Vector2(2.0, 2.0), 0.12)
    await pulse.finished
    spawn_sparkle_burst(screen_center, 32, [Color(1.0, 0.96, 0.85), Color(1.0, 0.84, 0.34), Color(0.68, 0.90, 1.0)], self, 130.0)
    _spawn_impact_ring(screen_center, Color(0.52, 0.92, 1.0), 5)

    var attack_gain: int = 1 if cost < 3 else (3 if cost == 3 else 4)
    var defense_gain: int = 0 if cost == 1 else (2 if cost == 2 else (3 if cost == 3 else 4))
    var stat_text := Label.new()
    stat_text.text = "+%d ATK  +%d DEF\nSPECIAL ABILITY" % [attack_gain, defense_gain]
    stat_text.position = Vector2(190, 588)
    stat_text.size = Vector2(900, 84)
    stat_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    stat_text.add_theme_font_size_override("font_size", ui_font(38))
    stat_text.add_theme_color_override("font_color", Color(1.0, 0.94, 0.72))
    stat_text.add_theme_color_override("font_shadow_color", Color.BLACK)
    stat_text.add_theme_constant_override("shadow_offset_x", 3)
    stat_text.add_theme_constant_override("shadow_offset_y", 3)
    stat_text.modulate.a = 0.0
    stat_text.z_index = 1300
    add_child(stat_text)

    var reveal := create_tween().set_parallel(true)
    reveal.tween_property(stat_text, "modulate:a", 1.0, 0.22)
    reveal.tween_property(ring_outer, "scale", Vector2(1.5, 1.5), 0.4)
    reveal.tween_property(ring_outer, "color:a", 0.0, 0.4)
    reveal.tween_property(ring_inner, "scale", Vector2(1.5, 1.5), 0.4)
    reveal.tween_property(ring_inner, "color:a", 0.0, 0.4)
    await reveal.finished
    await get_tree().create_timer(0.34).timeout

    spin.kill()
    var return_tween := create_tween().set_parallel(true)
    return_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
    return_tween.tween_property(card_view, "position", original_position, 0.32)
    return_tween.tween_property(card_view, "scale", original_scale, 0.32)
    return_tween.tween_property(dimmer, "color:a", 0.0, 0.28)
    return_tween.tween_property(backdrop_art, "modulate:a", 0.0, 0.26)
    return_tween.tween_property(beam_root, "modulate:a", 0.0, 0.24)
    return_tween.tween_property(title, "theme_override_colors/font_color:a", 0.0, 0.22)
    return_tween.tween_property(title_shadow_layer, "theme_override_colors/font_color:a", 0.0, 0.22)
    return_tween.tween_property(stat_text, "modulate:a", 0.0, 0.22)
    await return_tween.finished

    card_view.z_index = 0
    dimmer.queue_free()
    backdrop_art.queue_free()
    beam_root.queue_free()
    ring_outer.queue_free()
    ring_inner.queue_free()
    title.queue_free()
    title_shadow_layer.queue_free()
    stat_text.queue_free()
    if is_instance_valid(music_player):
        var restore := create_tween()
        restore.tween_property(music_player, "volume_db", old_music_db, 0.3)
    busy = false

func resolve_awakened_ability(follower: Dictionary, player_side: bool) -> void:
    var faction: String = str(follower.get("faction", "Universal"))
    if faction == "Serenity":
        if player_side:
            player_health = mini(STARTING_HEALTH, player_health + 3)
        else:
            enemy_health = mini(STARTING_HEALTH, enemy_health + 3)
        await show_vfx("AWAKENED: HEAL 3", player_leader.global_position if player_side else enemy_leader.global_position, Color(0.42, 1.0, 0.62))
    elif faction == "Courage":
        if player_side:
            enemy_health -= 2
        else:
            player_health -= 2
        await show_vfx("AWAKENED: DEAL 2", enemy_leader.global_position if player_side else player_leader.global_position, Color(1.0, 0.35, 0.22))
    elif faction == "Purpose":
        var board: Array = player_board if player_side else enemy_board
        for ally in board:
            ally["attack"] = int(ally.get("attack", 0)) + 1
            ally["health"] = int(ally.get("health", 0)) + 1
            ally["max_health"] = int(ally.get("max_health", ally.get("health", 0))) + 1
        await show_vfx("AWAKENED: ALL ALLIES +1/+1", area_center(player_side), Color(1.0, 0.85, 0.30))
    elif faction == "Hope":
        for i in range(2):
            draw_card(player_deck if player_side else enemy_deck, player_hand if player_side else enemy_hand)
        await show_vfx("AWAKENED: DRAW 2", Vector2(520, 475 if player_side else 70), Color(0.70, 0.58, 1.0))
    else:
        if player_side:
            player_max_mana = mini(MAX_MANA, player_max_mana + 1)
            player_mana = mini(player_max_mana, player_mana + 1)
        else:
            enemy_max_mana = mini(MAX_MANA, enemy_max_mana + 1)
            enemy_mana = mini(enemy_max_mana, enemy_mana + 1)
        await show_vfx("AWAKENED: +1 MAX PP", player_leader.global_position if player_side else enemy_leader.global_position, Color(0.55, 0.85, 1.0))
    check_winner()

func area_center(player_side: bool) -> Vector2:
    var area: Control = player_board_area if player_side else enemy_board_area
    return area.global_position + area.size * 0.5

func make_leader(label_text: String, pos: Vector2, player_side: bool) -> Button:
    var leader := Button.new()
    leader.position = pos
    leader.size = Vector2(200, 200)
    leader.text = ""
    leader.clip_contents = true
    leader.focus_mode = Control.FOCUS_NONE

    # No card-border styling — leaders feel like characters, not cards.
    var style_empty := StyleBoxEmpty.new()
    leader.add_theme_stylebox_override("normal",  style_empty)
    leader.add_theme_stylebox_override("hover",   style_empty)
    leader.add_theme_stylebox_override("pressed", style_empty)
    leader.add_theme_stylebox_override("focus",   style_empty)

    # Animated leader portrait — layered art (body/head/hair/blink/aura) with
    # idle breathing, hair sway, and blinking handled by LeaderView.
    # Class is set by update_leader_visual() once faction_name is known.
    var lv := _LeaderView.new()
    lv.name = "LeaderPortrait"
    lv.position = Vector2.ZERO
    lv.size = Vector2(200, 200)
    lv.mouse_filter = Control.MOUSE_FILTER_IGNORE
    leader.add_child(lv)

    # Gradient scrim fades the portrait into the name area.
    var scrim := ColorRect.new()
    scrim.name = "BottomScrim"
    scrim.position = Vector2(0, 150)
    scrim.size = Vector2(200, 50)
    scrim.color = Color(0.03, 0.05, 0.10, 0.90)
    scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
    leader.add_child(scrim)

    # Thin class accent line — coloured in _start_leader_class_aura().
    var accent_bar := ColorRect.new()
    accent_bar.name = "AccentBar"
    accent_bar.position = Vector2(0, 164)
    accent_bar.size = Vector2(200, 2)
    accent_bar.color = Color(1.0, 0.80, 0.34)
    accent_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    leader.add_child(accent_bar)

    # Leader name plate.
    var name_label := Label.new()
    name_label.name = "NameLabel"
    name_label.text = label_text
    name_label.position = Vector2(4, 167)
    name_label.size = Vector2(192, 30)
    name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    name_label.add_theme_font_size_override("font_size", ui_font(10))
    name_label.add_theme_color_override("font_color", Color(1.0, 0.91, 0.62))
    name_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.90))
    name_label.add_theme_constant_override("shadow_offset_x", 1)
    name_label.add_theme_constant_override("shadow_offset_y", 1)
    name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    leader.add_child(name_label)
    return leader

func _make_header_pill_button(label_text: String, pos: Vector2) -> Button:
    var button := Button.new()
    button.text = label_text
    button.position = pos
    button.size = Vector2(92, 34)
    button.focus_mode = Control.FOCUS_NONE
    button.add_theme_font_size_override("font_size", ui_font(13))
    button.add_theme_color_override("font_color", Color(0.88, 0.94, 0.98))
    button.add_theme_color_override("font_hover_color", Color(1.0, 0.91, 0.62))
    var normal := StyleBoxFlat.new()
    normal.bg_color = Color(0.07, 0.10, 0.15, 0.9)
    normal.border_color = Color(0.55, 0.62, 0.70, 0.7)
    normal.set_border_width_all(1)
    normal.set_corner_radius_all(17)
    button.add_theme_stylebox_override("normal", normal)
    var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
    hover.bg_color = Color(0.11, 0.16, 0.22, 0.95)
    hover.border_color = Color(0.96, 0.83, 0.45, 0.85)
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_stylebox_override("pressed", hover)
    return button

func make_hp_label(pos: Vector2, accent: Color = Color(1.0, 0.66, 0.56)) -> Label:
    # A compact badge meant to hang off the corner of a leader frame, so HP
    # reads as part of the portrait rather than a loose floating number.
    var label := Label.new(); label.position = pos; label.size = Vector2(92, 38); label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; label.add_theme_font_size_override("font_size", ui_font(20))
    label.add_theme_color_override("font_color", Color(1.0, 0.93, 0.90))
    label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
    label.add_theme_constant_override("shadow_offset_x", 1)
    label.add_theme_constant_override("shadow_offset_y", 1)
    var style := StyleBoxFlat.new(); style.bg_color = Color(0.42, 0.05, 0.08, 0.96); style.border_color = accent; style.set_border_width_all(2); style.set_corner_radius_all(18); style.shadow_color = Color(0, 0, 0, 0.6); style.shadow_size = 6; label.add_theme_stylebox_override("normal", style)
    return label


func start_online_host_match() -> void:
    seed(online_seed)
    game_over=false; busy=false; selected_attacker=-1; selected_evolution_cost=0
    player_evolutions_used=[false,false,false,false]; enemy_evolutions_used=[false,false,false,false]
    player_health=STARTING_HEALTH; enemy_health=STARTING_HEALTH
    player_mana=0; player_max_mana=0; enemy_mana=0; enemy_max_mana=0; turn_number=0
    player_momentum=0; enemy_momentum=0; momentum_used_this_turn=false
    player_hand.clear(); enemy_hand.clear(); player_board.clear(); enemy_board.clear(); player_relapse.clear(); enemy_relapse.clear()
    phoenix_pending_player = false; phoenix_pending_enemy = false; phoenix_tier_player = 1; phoenix_tier_enemy = 1
    player_deck = prepare_balanced_draw_order(build_deck_for_mode(selected_class, player_deck_mode))
    enemy_deck = prepare_balanced_draw_order(build_deck_for_mode(enemy_class, enemy_deck_mode))
    for i in range(4):
        draw_card(player_deck,player_hand); draw_card(enemy_deck,enemy_hand)
    player_goes_first=true
    update_leaders(); refresh_ui(); set_battle_music("battle_early_v2")
    await get_tree().create_timer(1.0).timeout
    NetworkManager.send_game({"event":"initial_state","state":serialize_online_state()})
    safe_set_text(status_label,"Opening hand — both players choose a Second Chance.")
    show_second_chance()

func serialize_online_state() -> Dictionary:
    return {
        "player_health":player_health,"enemy_health":enemy_health,
        "player_mana":player_mana,"enemy_mana":enemy_mana,
        "player_max_mana":player_max_mana,"enemy_max_mana":enemy_max_mana,
        "turn_number":turn_number,"player_deck":player_deck,"enemy_deck":enemy_deck,
        "player_hand":player_hand,"enemy_hand":enemy_hand,
        "player_board":player_board,"enemy_board":enemy_board,
        "player_relapse":player_relapse,"enemy_relapse":enemy_relapse,
        "player_momentum":player_momentum,"enemy_momentum":enemy_momentum,
        "player_evolutions_used":player_evolutions_used,"enemy_evolutions_used":enemy_evolutions_used,
        "selected_class":selected_class,"enemy_class":enemy_class,"game_over":game_over,"turn_owner":online_role if player_turn_active else ("join" if online_role=="host" else "host")
    }

func apply_online_state(remote: Dictionary) -> void:
    online_applying_state=true
    player_health=int(remote.get("enemy_health",STARTING_HEALTH)); enemy_health=int(remote.get("player_health",STARTING_HEALTH))
    player_mana=int(remote.get("enemy_mana",0)); enemy_mana=int(remote.get("player_mana",0))
    player_max_mana=int(remote.get("enemy_max_mana",0)); enemy_max_mana=int(remote.get("player_max_mana",0))
    turn_number=int(remote.get("turn_number",0))
    player_deck=remote.get("enemy_deck",[]).duplicate(true); enemy_deck=remote.get("player_deck",[]).duplicate(true)
    player_hand=remote.get("enemy_hand",[]).duplicate(true); enemy_hand=remote.get("player_hand",[]).duplicate(true)
    player_board=remote.get("enemy_board",[]).duplicate(true); enemy_board=remote.get("player_board",[]).duplicate(true)
    player_relapse=remote.get("enemy_relapse",[]).duplicate(true); enemy_relapse=remote.get("player_relapse",[]).duplicate(true)
    player_momentum=int(remote.get("enemy_momentum",0)); enemy_momentum=int(remote.get("player_momentum",0))
    player_evolutions_used=remote.get("enemy_evolutions_used",[false,false,false,false]).duplicate()
    enemy_evolutions_used=remote.get("player_evolutions_used",[false,false,false,false]).duplicate()
    selected_class=str(remote.get("enemy_class",selected_class)); enemy_class=str(remote.get("selected_class",enemy_class))
    game_over=bool(remote.get("game_over",false))
    var owner_role := str(remote.get("turn_owner", ""))
    if not owner_role.is_empty():
        player_turn_active = owner_role == online_role
        busy = not player_turn_active
    update_leaders(); refresh_ui(); online_applying_state=false

func send_online_snapshot(event_name: String="state") -> void:
    if online_mode and online_match_started and not online_applying_state:
        await NetworkManager.send_game({"event":event_name,"state":serialize_online_state()})

func _on_online_game_message(payload: Dictionary) -> void:
    if not online_mode: return
    var event_name:=str(payload.get("event",""))
    match event_name:
        "initial_state":
            if online_role=="join":
                apply_online_state(payload.get("state",{})); online_waiting_for_initial=false
                safe_set_text(status_label,"Opening hand — choose your Second Chance."); show_second_chance()
        "snapshot":
            apply_online_state(payload.get("state",{}))
        "battle_begin":
            online_match_started=true
            var first_role:=str(payload.get("first_role","host"))
            if online_role==first_role:
                safe_set_text(status_label,"You take the first turn."); start_player_turn()
            else:
                player_turn_active=false; busy=true; safe_set_text(status_label,"Opponent takes the first turn."); refresh_ui()
        "state":
            if not player_turn_active: apply_online_state(payload.get("state",{}))
        "end_turn":
            apply_online_state(payload.get("state",{}))
            if player_turn_active:
                busy=false
                start_player_turn()
            else:
                safe_set_text(status_label,"Opponent's turn...")
                refresh_ui()
        "game_over":
            apply_online_state(payload.get("state",{}))
        "opponent_left":
            player_turn_active=false; busy=true; safe_set_text(status_label,"Your opponent disconnected.")

func _on_online_disconnected(reason: String) -> void:
    if online_mode:
        player_turn_active=false; busy=true; safe_set_text(status_label,"Online match disconnected: %s" % reason)

func training_resource_name(class_name_value: String) -> String:
    match class_name_value:
        "Courage": return "RESOLVE"
        "Hope": return "HOPE"
        "Serenity": return "PEACE"
        _: return "PROGRESS"

func training_objectives(class_name_value: String) -> Array[String]:
    match class_name_value:
        "Courage":
            return [
                "Play a Courage follower",
                "Attack an enemy follower",
                "Survive combat to gain Resolve",
                "Destroy an enemy follower",
                "Spend 2 Resolve",
                "Win the training battle"
            ]
        "Hope":
            return [
                "Play a Hope follower",
                "Restore Defense to your Leader",
                "Send a follower to the Relapse Zone",
                "Recover a follower from the Relapse Zone",
                "Spend 2 Hope",
                "Win the training battle"
            ]
        "Serenity":
            return [
                "Play a Recovery Skill",
                "Restore Defense to your Leader",
                "End a turn without attacking",
                "Trigger Sanctuary to permanently buff an ally",
                "Spend 2 Peace",
                "Win the training battle"
            ]
        _:
            return [
                "Play Daily Progress",
                "Spend all of your Play Points",
                "Trigger Daily Progress twice",
                "Reach 3 Progress and gain maximum PP",
                "Play Walking Free",
                "Win the training battle"
            ]

func training_prompt_for_current_objective() -> String:
    var resource := training_resource_name(training_class)
    var objectives := training_objectives(training_class)
    if training_objective_index >= objectives.size():
        return "Lesson complete. Finish the battle to graduate."
    match training_class:
        "Courage":
            var prompts := [
                "Play a follower so you can begin fighting for the board.",
                "Select your follower, then select an enemy follower.",
                "A follower that survives combat earns Resolve.",
                "Finish an enemy follower to earn more Resolve.",
                "Tap the %s tracker when it reaches 2 to spend it for +1/+1." % resource,
                "Use what you learned and win."
            ]
            return prompts[training_objective_index]
        "Hope":
            var prompts := [
                "Play a follower that can support your recovery plan.",
                "Use a healing card after your Leader has taken damage.",
                "Let one of your followers be defeated so it enters the Relapse Zone.",
                "Use a recovery effect to bring that follower back.",
                "Tap the %s tracker at 2 to restore 2 Defense." % resource,
                "Outlast the opponent and win."
            ]
            return prompts[training_objective_index]
        "Serenity":
            var prompts := [
                "Play Sanctuary of Serenity or another Recovery Skill into the Skill row.",
                "Heal your Leader to build Peace and activate your engine.",
                "End a turn without attacking. Patience builds Peace.",
                "Heal while Sanctuary is active to permanently strengthen an ally.",
                "Tap the %s tracker at 2 to protect your board." % resource,
                "Control the pace and win."
            ]
            return prompts[training_objective_index]
        _:
            var prompts := [
                "Play Daily Progress into the Recovery Skill row.",
                "Use every Play Point before ending your turn.",
                "Empty your Play Points twice to trigger Daily Progress twice.",
                "Reach 3 Progress to gain an extra maximum Play Point.",
                "Build to 6 Progress, then play Walking Free.",
                "Complete the journey and win."
            ]
            return prompts[training_objective_index]

func show_class_training_panel() -> void:
    if not training_mode:
        return
    if is_instance_valid(training_panel):
        training_panel.queue_free()
    training_panel = Panel.new()
    training_panel.position = Vector2(250, 18)
    training_panel.size = Vector2(780, 132)
    training_panel.z_index = 3500
    var panel_style := StyleBoxFlat.new()
    panel_style.bg_color = Color(0.015, 0.025, 0.055, 0.97)
    panel_style.border_color = class_accent_color(training_class)
    panel_style.set_border_width_all(3)
    panel_style.set_corner_radius_all(16)
    training_panel.add_theme_stylebox_override("panel", panel_style)
    add_child(training_panel)

    var title := Label.new()
    title.text = "%s TRAINING" % training_class.to_upper()
    title.position = Vector2(18, 8)
    title.size = Vector2(250, 28)
    title.add_theme_font_size_override("font_size", ui_font(20))
    title.add_theme_color_override("font_color", class_accent_color(training_class).lightened(0.25))
    training_panel.add_child(title)

    training_resource_label = Label.new()
    training_resource_label.position = Vector2(540, 8)
    training_resource_label.size = Vector2(220, 30)
    training_resource_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    training_resource_label.add_theme_font_size_override("font_size", ui_font(19))
    training_resource_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.34))
    training_resource_label.mouse_filter = Control.MOUSE_FILTER_STOP
    training_resource_label.gui_input.connect(_on_training_resource_input)
    training_panel.add_child(training_resource_label)

    training_objective_label = Label.new()
    training_objective_label.position = Vector2(20, 40)
    training_objective_label.size = Vector2(740, 34)
    training_objective_label.add_theme_font_size_override("font_size", ui_font(17))
    training_objective_label.add_theme_color_override("font_color", Color(0.94, 0.96, 1.0))
    training_panel.add_child(training_objective_label)

    training_prompt_label = Label.new()
    training_prompt_label.position = Vector2(20, 76)
    training_prompt_label.size = Vector2(740, 46)
    training_prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    training_prompt_label.add_theme_font_size_override("font_size", ui_font(14))
    training_prompt_label.add_theme_color_override("font_color", Color(0.76, 0.86, 1.0))
    training_panel.add_child(training_prompt_label)
    update_training_panel()

func update_training_panel() -> void:
    if not training_mode or not is_instance_valid(training_panel):
        return
    var objectives := training_objectives(training_class)
    var objective_text := "Training complete"
    if training_objective_index < objectives.size():
        objective_text = "OBJECTIVE %d/%d  •  %s" % [training_objective_index + 1, objectives.size(), objectives[training_objective_index]]
    safe_set_text(training_objective_label, objective_text)
    safe_set_text(training_prompt_label, training_prompt_for_current_objective())
    safe_set_text(training_resource_label, "%s: %d  •  TAP TO SPEND" % [training_resource_name(training_class), training_resource_value])

func training_advance(expected_index: int, message: String, resource_gain: int = 0) -> void:
    if not training_mode or training_objective_index != expected_index:
        return
    training_resource_value += resource_gain
    training_objective_index += 1
    safe_set_text(status_label, message)
    show_vfx("OBJECTIVE COMPLETE", Vector2(510, 165), class_accent_color(training_class))
    update_training_panel()

func training_gain_resource(amount: int, reason: String) -> void:
    if not training_mode or amount <= 0:
        return
    training_resource_value += amount
    safe_set_text(status_label, "+%d %s — %s" % [amount, training_resource_name(training_class), reason])
    show_vfx("+%d %s" % [amount, training_resource_name(training_class)], Vector2(880, 165), class_accent_color(training_class))
    update_training_panel()

func _on_training_resource_input(event: InputEvent) -> void:
    if not training_mode or not (event is InputEventMouseButton) or not event.pressed:
        return
    if training_resource_value < 2:
        safe_set_text(status_label, "You need 2 %s to use the training effect." % training_resource_name(training_class))
        return
    var spend_index := 4
    if training_objective_index != spend_index:
        safe_set_text(status_label, "Save your %s until the lesson asks you to spend it." % training_resource_name(training_class))
        return
    training_resource_value -= 2
    training_spent_resource = true
    match training_class:
        "Courage":
            if not player_board.is_empty():
                player_board[0]["attack"] = int(player_board[0].get("attack", 0)) + 1
                player_board[0]["health"] = int(player_board[0].get("health", 0)) + 1
                player_board[0]["max_health"] = int(player_board[0].get("max_health", player_board[0].get("health", 0))) + 1
        "Hope":
            player_health = mini(STARTING_HEALTH, player_health + 2)
        "Serenity":
            for ally in player_board:
                if not bool(ally.get("is_amulet", false)):
                    ally["health"] = int(ally.get("health", 0)) + 1
                    ally["max_health"] = int(ally.get("max_health", ally.get("health", 0))) + 1
        _:
            player_mana = mini(MAX_MANA + 1, player_mana + 1)
    training_advance(4, "%s spent successfully." % training_resource_name(training_class), 0)
    refresh_ui()

func training_on_card_played(card_data: Dictionary) -> void:
    _tutorial_on_card_played(card_data)
    if not training_mode:
        return
    var faction := str(card_data.get("faction", ""))
    var ability := str(card_data.get("ability", ""))
    var card_name := str(card_data.get("name", ""))
    if training_class == "Courage" and training_objective_index == 0 and faction == "Courage":
        training_played_follower = true
        training_advance(0, "Follower played. Now attack an enemy follower.")
    elif training_class == "Hope" and training_objective_index == 0 and faction == "Hope":
        training_played_follower = true
        training_advance(0, "Hope follower played. Now restore your Leader's Defense.")
    elif training_class == "Serenity" and training_objective_index == 0 and bool(card_data.get("is_amulet", false)):
        training_played_skill = true
        training_gain_resource(1, "Recovery Skill played")
        training_advance(0, "Recovery Skill active. Now heal your Leader.")
    elif training_class == "Purpose" and training_objective_index == 0 and (card_name == "Daily Progress" or ability == "daily_progress"):
        training_played_skill = true
        training_advance(0, "Daily Progress is active. Spend every Play Point.")
    elif training_class == "Purpose" and training_objective_index == 4 and card_name == "Walking Free":
        training_advance(4, "Walking Free reached. Finish the battle.")

func training_on_heal(amount: int) -> void:
    if not training_mode or amount <= 0:
        return
    training_healed = true
    if training_class == "Hope":
        training_gain_resource(1, "Leader healed")
        training_advance(1, "Healing builds Hope. Now let a follower enter the Relapse Zone.")
    elif training_class == "Serenity":
        training_gain_resource(1, "Leader healed")
        if training_objective_index == 1:
            training_advance(1, "Healing builds Peace. End your next turn without attacking.")
        elif training_objective_index == 3 and training_played_skill:
            for ally in player_board:
                if not bool(ally.get("is_amulet", false)):
                    ally["attack"] = int(ally.get("attack", 0)) + 1
                    ally["health"] = int(ally.get("health", 0)) + 1
                    ally["max_health"] = int(ally.get("max_health", ally.get("health", 0))) + 1
                    break
            training_advance(3, "Sanctuary permanently strengthened an ally.", 1)

func training_on_attack(target_index: int, attacker_survived: bool, enemy_destroyed: bool) -> void:
    _tutorial_on_attack(target_index, attacker_survived, enemy_destroyed)
    if not training_mode:
        return
    training_attacked_this_turn = true
    if training_class == "Courage":
        if training_objective_index == 1 and target_index >= 0:
            training_advance(1, "Combat started. Keep your follower alive to build Resolve.")
        if attacker_survived:
            training_survived_combat = true
            training_gain_resource(1, "Follower survived combat")
            training_advance(2, "Your follower survived and earned Resolve.")
        if enemy_destroyed:
            training_destroyed_enemy = true
            training_gain_resource(1, "Enemy follower defeated")
            training_advance(3, "Defeating an enemy earned more Resolve. Spend 2 Resolve.")

func training_on_follower_lost(player_side: bool) -> void:
    _tutorial_on_follower_lost(player_side)
    if not training_mode or not player_side:
        return
    if training_class == "Hope" and training_objective_index == 2:
        training_advance(2, "The follower entered the Relapse Zone. Recover it now.")

func training_on_recovered(player_side: bool) -> void:
    _tutorial_on_recovered(player_side)
    if not training_mode or not player_side:
        return
    training_recovered = true
    if training_class == "Hope":
        training_gain_resource(1, "Follower recovered")
        training_advance(3, "Recovery builds Hope. Spend 2 Hope.")

func training_on_end_turn() -> void:
    if not training_mode:
        return
    if training_class == "Serenity" and training_objective_index == 2 and not training_attacked_this_turn:
        training_gain_resource(1, "Turn ended without attacking")
        training_advance(2, "Patience builds Peace. Heal again to trigger Sanctuary's buff.")
    if training_class == "Purpose" and player_mana == 0:
        training_progress_trigger_count += 1
        training_gain_resource(1, "All Play Points spent")
        if training_objective_index == 1:
            training_advance(1, "Efficient play builds Progress. Trigger it one more time.")
        elif training_objective_index == 2 and training_progress_trigger_count >= 2:
            training_advance(2, "Daily Progress triggered twice. Reach 3 Progress.")
        elif training_objective_index == 3 and training_resource_value >= 3:
            player_max_mana = mini(MAX_MANA, player_max_mana + 1)
            training_advance(3, "3 Progress earned an extra maximum Play Point. Build toward Walking Free.")
    training_attacked_this_turn = false
    update_training_panel()

# ══════════════════════════════════════════════════════════════════════════════
#  TUTORIAL MODE — followers-on-the-field Academy lessons
#  Each of the six battle lessons is driven by tutorial_lesson (1-6) and a
#  tutorial_step counter incremented by the validation hooks below.
# ══════════════════════════════════════════════════════════════════════════════

func _tut_card(name_v:String,cost_v:int,atk_v:int,hp_v:int,faction_v:String,ability_v:String,text_v:String,icon_v:String,art_v:String="") -> Dictionary:
    if art_v != "":
        return card(name_v,cost_v,atk_v,hp_v,faction_v,"Training",ability_v,0,text_v,icon_v,art_v)
    return card(name_v,cost_v,atk_v,hp_v,faction_v,"Training",ability_v,0,text_v,icon_v)

func _setup_tutorial_lesson() -> void:
    player_board.clear(); enemy_board.clear()
    match tutorial_lesson:
        0: # Zone orientation — empty board so the real UI is unobstructed
            player_mana = 3; player_max_mana = 3
        1: # Play a Follower
            player_mana = 3; player_max_mana = 3
            player_hand.append(_tut_card("Newcomer",1,1,2,"Universal","none","Play this to put a follower on the field.","road"))
            player_hand.append(_tut_card("Forward Vanguard",3,4,2,"Courage","charge","Charge — attacks the same turn it enters play.","flame"))
        2: # Combat
            player_mana = 2; player_max_mana = 2
            player_hand.append(_tut_card("Spark Runner",1,2,1,"Courage","charge","Charge.","flame"))
            var trainee := _tut_card("Academy Trainee",2,4,5,"Hope","none","Select this follower, then click an enemy target to attack.","hands")
            trainee["can_attack"] = true; trainee["summoned_turn"] = -1
            player_board.append(trainee)
            var guard := _tut_card("Enemy Guard",2,2,4,"Courage","guard","Guard — must be attacked before the enemy Leader.","shield")
            guard["can_attack"] = true; guard["summoned_turn"] = -1
            enemy_board.append(guard)
        3: # End Your Turn
            player_mana = 3; player_max_mana = 3
            player_hand.append(_tut_card("Newcomer",1,1,2,"Universal","none","Play this follower, then click End Turn.","road"))
            player_hand.append(_tut_card("Patient Listener",2,2,4,"Serenity","none","On Play: Draw a card.","hands"))
        4: # Spells & Amulets
            player_mana = 6; player_max_mana = 6
            var spell_card := card("Step Study",3,0,0,"Universal","Silver","draw_reduce",1,"Spell — Play: Draw a card, then reduce the highest-cost card in hand by 1.","road")
            spell_card["is_spell"] = true
            player_hand.append(spell_card)
            var found_amulet := _find_card_by_name(build_class_cards("Purpose"), "Daily Progress")
            if not found_amulet.is_empty():
                player_hand.append(found_amulet)
            else:
                var amulet_card := _tut_card("Recovery Amulet",2,0,0,"Universal","none","Amulet — stays on the board and generates an effect each turn.","star")
                amulet_card["is_amulet"] = true
                player_hand.append(amulet_card)
        5: # Recovery Skill — class-aware (Hope, Courage, Serenity, Purpose each see
           #                their own mechanic rather than a generic revive lesson)
            match selected_class:
                "Courage":
                    player_mana = 4; player_max_mana = 4
                    var cour_ally := _tut_card("Frontline Fighter",2,3,3,"Courage","none","Your follower. After playing the amulet, select it and attack the enemy leader directly.","flame")
                    cour_ally["can_attack"] = true; cour_ally["summoned_turn"] = -1
                    player_board.append(cour_ally)
                    player_hand.append(_tut_card("Face It Head-On",2,0,0,"Courage","standing_ground","Amulet — Gain Progress whenever you attack the enemy leader directly. At 3 Progress, all allies gain permanent +1 Attack.","flame"))
                "Serenity":
                    player_mana = 5; player_max_mana = 5
                    player_hand.append(_tut_card("Sanctuary of Serenity",2,0,0,"Serenity","sanctuary_serenity","Amulet — Whenever your leader's Defense is restored, permanently give an allied follower +1/+1.","shield"))
                    # Guiding Light uses heal_leader with value 3, which needs the
                    # ability_param slot — use card() directly instead of _tut_card().
                    player_hand.append(card("Guiding Light",1,1,2,"Serenity","Training","heal_leader",3,"Arrival: Restore 3 Defense. Use this to trigger Sanctuary of Serenity's buff.","hands"))
                "Purpose":
                    player_mana = 2; player_max_mana = 2
                    player_hand.append(_tut_card("Daily Progress",2,0,0,"Purpose","daily_progress","Amulet — End a turn with 0 Play Points to gain Progress. At 3, gain +1 maximum PP.","road"))
                _: # Hope (and any unexpected value — keep the original revive lesson)
                    player_mana = 3; player_max_mana = 3
                    var hope_ally := _tut_card("Academy Rookie",2,2,3,"Hope","none","Your follower on the field.","hands")
                    hope_ally["can_attack"] = false; hope_ally["summoned_turn"] = turn_number
                    player_board.append(hope_ally)
                    player_hand.append(_tut_card("Recovery Call",3,2,3,"Hope","revive","On Play: Recover the most recent follower from your Relapse Zone.","star"))
                    var punisher := _tut_card("Aggressive Trainer",3,4,4,"Courage","none","Scripted — will attack your follower this turn.","flame")
                    punisher["can_attack"] = true; punisher["summoned_turn"] = -1
                    enemy_board.append(punisher)
        6: # Sponsor & Sponsee
            player_mana = 8; player_max_mana = 8
            var sponsor_card := _find_card_by_name(build_universal_cards(), "The Sponsor")
            if not sponsor_card.is_empty():
                player_hand.append(sponsor_card)
            else:
                player_hand.append(card("The Sponsor",8,5,9,"Universal","Platinum","sponsor",0,"SIGNATURE PLATINUM — Arrival: Summon 2 Sponsees.","star"))

func _build_tutorial_overlay() -> void:
    if is_instance_valid(tutorial_overlay):
        tutorial_overlay.queue_free()
    tutorial_overlay = Panel.new()
    tutorial_overlay.position = Vector2(0, 0)
    tutorial_overlay.size = Vector2(1280, 106)
    tutorial_overlay.z_index = 3500
    tutorial_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var st := StyleBoxFlat.new()
    st.bg_color = Color(0.01, 0.02, 0.06, 0.97)
    st.border_color = Color(0.95, 0.78, 0.34)
    st.border_width_bottom = 3
    tutorial_overlay.add_theme_stylebox_override("panel", st)
    safe_add_child(self, tutorial_overlay)

    # Mentor accent bar
    var bar := ColorRect.new(); bar.color = class_accent_color(selected_class)
    bar.position = Vector2(0, 0); bar.size = Vector2(6, 106)
    bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    tutorial_overlay.add_child(bar)

    # Lesson / mentor label
    tutorial_heading_label = Label.new()
    tutorial_heading_label.position = Vector2(16, 7)
    tutorial_heading_label.size = Vector2(1240, 22)
    tutorial_heading_label.add_theme_font_size_override("font_size", ui_font(13))
    tutorial_heading_label.add_theme_color_override("font_color", Color(0.95, 0.78, 0.34))
    var lesson_names := ["Play a Follower","Combat","End Your Turn","Spells & Amulets","Recovery & Revive","Sponsor & Sponsee"]
    var mentor_names := ["Dawn","Marcus","Marcus","Priya","Dawn","Theo"]
    var safe_idx := clampi(tutorial_lesson - 1, 0, lesson_names.size() - 1)
    tutorial_heading_label.text = "RECOVERY ACADEMY  •  %s  •  %s" % [lesson_names[safe_idx], mentor_names[safe_idx]]
    tutorial_overlay.add_child(tutorial_heading_label)

    # Step separator
    var sep := ColorRect.new(); sep.color = Color(1,1,1,0.08)
    sep.position = Vector2(16,32); sep.size = Vector2(1248,1)
    sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
    tutorial_overlay.add_child(sep)

    # Instruction label
    tutorial_instruction_label = Label.new()
    tutorial_instruction_label.position = Vector2(16, 38)
    tutorial_instruction_label.size = Vector2(1248, 62)
    tutorial_instruction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    tutorial_instruction_label.add_theme_font_size_override("font_size", ui_font(18))
    tutorial_instruction_label.add_theme_color_override("font_color", Color(0.94, 0.96, 1.0))
    tutorial_overlay.add_child(tutorial_instruction_label)

    _tutorial_set_instruction(_tutorial_opening_text())
    if tutorial_lesson == 0:
        call_deferred("_build_zone_highlights")

func _build_zone_highlights() -> void:
    # Zone data: [label, why, position, size, color]
    var zones := [
        ["YOUR LEADER", "20 Defense — when it hits 0 you lose.", Vector2(1062, 335), Vector2(195, 185), Color(0.90, 0.22, 0.22)],
        ["YOUR HAND", "Cards you can play this turn.", Vector2(150, 600), Vector2(880, 115), Color(0.22, 0.52, 0.90)],
        ["PLAY POINTS", "Spent to play cards. Grows by 1 each turn.", Vector2(1028, 548), Vector2(232, 100), Color(0.95, 0.78, 0.10)],
        ["BATTLEFIELD", "Where your followers fight.", Vector2(245, 365), Vector2(790, 165), Color(0.22, 0.72, 0.38)],
        ["ENEMY LEADER", "What you're trying to bring to zero.", Vector2(24, 92), Vector2(195, 185), Color(0.75, 0.28, 0.82)],
    ]
    var tapped := [0]
    var total := zones.size()
    for zone_data in zones:
        var zone_label: String = zone_data[0]
        var zone_why: String = zone_data[1]
        var zone_pos: Vector2 = zone_data[2]
        var zone_size: Vector2 = zone_data[3]
        var zone_color: Color = zone_data[4]

        var glow := Panel.new()
        glow.position = zone_pos
        glow.size = zone_size
        glow.z_index = 3400
        glow.mouse_filter = Control.MOUSE_FILTER_STOP
        var sb := StyleBoxFlat.new()
        sb.bg_color = Color(zone_color.r, zone_color.g, zone_color.b, 0.18)
        sb.border_color = zone_color
        sb.set_border_width_all(4)
        sb.set_corner_radius_all(14)
        glow.add_theme_stylebox_override("panel", sb)
        safe_add_child(self, glow)

        # Pulsing glow tween
        var pulse := create_tween()
        pulse.set_loops()
        pulse.tween_property(glow, "modulate:a", 0.55, 0.7).set_trans(Tween.TRANS_SINE)
        pulse.tween_property(glow, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_SINE)

        # Label inside
        var name_lbl := Label.new()
        name_lbl.text = zone_label
        name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        name_lbl.position = Vector2(0, 0)
        name_lbl.size = zone_size
        name_lbl.add_theme_font_size_override("font_size", ui_font(18))
        name_lbl.add_theme_color_override("font_color", zone_color.lightened(0.5))
        name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
        glow.add_child(name_lbl)

        # Tap to confirm
        var tapped_zone := [false]
        glow.gui_input.connect(func(ev: InputEvent):
            if not (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT): return
            if tapped_zone[0]: return
            tapped_zone[0] = true
            pulse.kill()
            var done_sb := StyleBoxFlat.new()
            done_sb.bg_color = Color(zone_color.r, zone_color.g, zone_color.b, 0.45)
            done_sb.border_color = Color(0.5, 1.0, 0.5)
            done_sb.set_border_width_all(4)
            done_sb.set_corner_radius_all(14)
            glow.add_theme_stylebox_override("panel", done_sb)
            safe_set_text(name_lbl, zone_label + " ✓")
            name_lbl.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
            _tutorial_set_instruction("%s — %s  (%d / %d)" % [zone_label, zone_why, tapped[0] + 1, total])
            tapped[0] += 1
            if tapped[0] >= total:
                get_tree().create_timer(0.6).timeout.connect(_tutorial_complete)
        )

func _tutorial_opening_text() -> String:
    match tutorial_lesson:
        0: return "Tap each glowing zone to learn what it does."
        1: return "You have 3 Play Points. Click a card in your hand to select it, then click 'Play Card' to put a follower on the battlefield."
        2: return "Your follower is already on the field. Click it to select it, then click the Enemy Guard to attack."
        3: return "You have 3 Play Points. Play a follower from your hand, then click 'End Turn' to pass."
        4: return "You have 6 Play Points. Spells resolve immediately — play Step Study from your hand first."
        5:
            match selected_class:
                "Courage": return "Play Face It Head-On from your hand, then select your follower and attack the enemy leader directly to earn your first Recovery Progress."
                "Serenity": return "Play Sanctuary of Serenity first, then play Guiding Light — restoring your leader's Defense will trigger Sanctuary's ally buff."
                "Purpose": return "Play Daily Progress (costs exactly 2 PP — all you have). Then click End Turn to trigger its first Progress."
                _: return "You have a follower on the field. Click 'End Turn' — watch what the opponent does."
        6: return "You have 8 Play Points. Play The Sponsor — it summons Sponsees to fight alongside you."
    return ""

func _tutorial_set_instruction(text: String) -> void:
    if is_instance_valid(tutorial_instruction_label):
        tutorial_instruction_label.text = text

func _tutorial_advance(next_text: String) -> void:
    tutorial_step += 1
    safe_set_text(status_label, next_text)
    _tutorial_set_instruction(next_text)

func _tutorial_complete() -> void:
    if not is_instance_valid(self): return
    # Guard: this function may be wired to a timer via .connect() AND called
    # directly — without this check a double-fire would increment the saved
    # step twice and change scene twice, corrupting Academy progress.
    if _tutorial_complete_called: return
    _tutorial_complete_called = true
    var vfx_color := class_accent_color(selected_class)
    show_vfx("LESSON COMPLETE  ✓", Vector2(440, 300), vfx_color)
    _tutorial_set_instruction("Lesson complete! Returning to the Academy…")
    # Do NOT increment academy.step here. menu.gd is the sole owner of
    # Academy progression. Writing step+1 here would cause a double-advance
    # because menu.gd reads the profile on return and then also increments
    # through complete_academy_lesson_once(). Only flag the battle_setup.cfg
    # so menu.gd's _ready() can detect the return and advance exactly once.
    var bs := ConfigFile.new()
    bs.load("user://battle_setup.cfg")
    bs.set_value("tutorial", "lesson_complete", true)
    bs.save("user://battle_setup.cfg")
    # Capture the SceneTree before the lambda so it doesn't need `self`
    # to be valid when the timer fires — if the battle node is freed first,
    # calling get_tree() through the implicit self would silently fail and
    # leave the player stuck on the "Returning to the Academy…" banner.
    var _tree := get_tree()
    _tree.create_timer(1.6).timeout.connect(func(): _tree.change_scene_to_file("res://main.tscn"))

# ── Per-lesson event hooks ────────────────────────────────────────────────────

func _tutorial_on_card_played(card_data: Dictionary) -> void:
    if not tutorial_mode: return
    var is_spell := bool(card_data.get("is_spell", false))
    var is_amulet := bool(card_data.get("is_amulet", false))
    var ability := str(card_data.get("ability", ""))
    print("TUTORIAL[L%d,S%d]: card_played ability=%s spell=%s amulet=%s" % [tutorial_lesson, tutorial_step, ability, str(is_spell), str(is_amulet)])
    match tutorial_lesson:
        1:
            if tutorial_step == 0:
                _tutorial_advance("Your follower is on the battlefield! Now click 'End Turn' to finish your turn.")
        3:
            if tutorial_step == 0 and not is_spell and not is_amulet:
                _tutorial_advance("Your follower is on the field. Now click 'End Turn' to pass to the opponent.")
        4:
            if tutorial_step == 0 and is_spell:
                _tutorial_advance("The spell resolved instantly — no follower placed! Now play the Amulet (Daily Progress) to see how it stays on the board.")
            elif tutorial_step == 1 and is_amulet:
                _tutorial_advance("Amulets persist and keep ticking. End your turn to see it resolve again next turn.")
        5:
            match selected_class:
                "Courage":
                    if tutorial_step == 0 and is_amulet:
                        _tutorial_advance("Face It Head-On is on the board! Select your follower and click the enemy leader portrait to attack directly and earn Recovery Progress.")
                "Serenity":
                    if tutorial_step == 0 and is_amulet:
                        _tutorial_advance("Sanctuary of Serenity is live. Now play Guiding Light to restore your leader's Defense and trigger Sanctuary's buff.")
                    elif tutorial_step == 1 and not is_amulet and not is_spell:
                        print("TUTORIAL[L5,Serenity,S1]: healer played → Sanctuary triggers → complete")
                        _tutorial_advance("Sanctuary triggered — an allied follower gained +1/+1! Each time your Defense is restored, Sanctuary buffs another ally. Lesson complete.")
                        await get_tree().create_timer(1.2).timeout
                        _tutorial_complete()
                "Purpose":
                    if tutorial_step == 0 and is_amulet:
                        _tutorial_advance("Daily Progress is tracking. You have 0 Play Points left — click End Turn to trigger your first Progress.")
                _: # Hope default
                    if tutorial_step == 1 and ability == "revive":
                        print("TUTORIAL[L5,Hope,S1]: revive card played — timer 1.2s then complete")
                        _tutorial_advance("Your follower is back from the Relapse Zone! Recovery is core to the Hope path. Lesson complete.")
                        await get_tree().create_timer(1.2).timeout
                        print("TUTORIAL[L5]: revive timer done → _tutorial_complete")
                        _tutorial_complete()
        6:
            if tutorial_step == 0 and ability == "sponsor":
                _tutorial_advance("Two Sponsees entered the field! Click 'End Turn' to see a third arrive automatically.")

func _tutorial_on_end_turn() -> void:
    if not tutorial_mode: return
    print("TUTORIAL[L%d,S%d]: end_turn fired" % [tutorial_lesson, tutorial_step])
    match tutorial_lesson:
        1:
            if tutorial_step == 1:
                print("TUTORIAL[L1,S1]: end_turn → complete, awaiting 0.9s timer")
                _tutorial_advance("Turn ended — your Play Points will refresh next turn. Lesson complete!")
                await get_tree().create_timer(0.9).timeout
                print("TUTORIAL[L1]: 0.9s timer done → _tutorial_complete")
                _tutorial_complete()
        3:
            if tutorial_step == 1:
                print("TUTORIAL[L3,S1]: end_turn → complete, awaiting 0.9s timer")
                _tutorial_advance("Your Play Points refreshed and you drew a new card. Each turn your maximum grows by 1. Lesson complete!")
                await get_tree().create_timer(0.9).timeout
                print("TUTORIAL[L3]: 0.9s timer done → _tutorial_complete")
                _tutorial_complete()
        4:
            if tutorial_step == 2:
                print("TUTORIAL[L4,S2]: end_turn → complete, awaiting 0.9s timer")
                _tutorial_advance("The Amulet triggered at end of turn. Lesson complete!")
                await get_tree().create_timer(0.9).timeout
                print("TUTORIAL[L4]: 0.9s timer done → _tutorial_complete")
                _tutorial_complete()
        # LESSON 5 — Hope path: do NOT advance on end_turn.
        # _tutorial_on_end_turn fires synchronously at the TOP of end_player_turn(),
        # BEFORE enemy_turn() runs. Advancing tutorial_step here (0 → 1) causes
        # _run_tutorial_enemy_turn to see step=1 instead of 0, so the enemy never
        # attacks the player's follower, nothing enters the Relapse Zone, the revive
        # card can never complete, and the lesson freezes permanently.
        # The step advancement for Hope belongs in _tutorial_on_follower_lost.
        # Purpose is handled here at step=1, which is AFTER the amulet is played
        # (step 0→1 happens in _tutorial_on_card_played), so the race condition
        # described above does not apply.
        5:
            if selected_class == "Purpose" and tutorial_step == 1:
                print("TUTORIAL[L5,Purpose,S1]: end_turn → complete")
                _tutorial_advance("Daily Progress triggered! Spend all your Play Points every turn to earn Progress and power up the Purpose path. Lesson complete.")
                await get_tree().create_timer(0.9).timeout
                _tutorial_complete()
        6:
            if tutorial_step == 1:
                print("TUTORIAL[L6,S1]: end_turn → complete, awaiting 1.1s timer")
                _tutorial_advance("A third Sponsee arrived automatically! The Sponsor keeps building your board every turn. Lesson complete!")
                await get_tree().create_timer(1.1).timeout
                print("TUTORIAL[L6]: 1.1s timer done → _tutorial_complete")
                _tutorial_complete()

func _tutorial_on_attack(target_index: int, _survived: bool, enemy_destroyed: bool) -> void:
    if not tutorial_mode: return
    print("TUTORIAL[L%d,S%d]: attack fired target=%d destroyed=%s" % [tutorial_lesson, tutorial_step, target_index, str(enemy_destroyed)])
    match tutorial_lesson:
        2:
            if tutorial_step == 0 and target_index >= 0:
                if enemy_destroyed or enemy_board.is_empty():
                    _tutorial_advance("Guard cleared! Now attack the enemy Leader — click your follower, then click the enemy Leader portrait.")
                else:
                    _tutorial_advance("You struck the Guard — keep attacking it until it falls, then go for the Leader.")
            elif tutorial_step == 1 and target_index < 0:
                print("TUTORIAL[L2,S1]: leader hit → complete, awaiting 0.9s timer")
                _tutorial_advance("Direct hit! That's combat — clear the path, then strike the Leader. Lesson complete!")
                await get_tree().create_timer(0.9).timeout
                print("TUTORIAL[L2]: 0.9s timer done → _tutorial_complete")
                _tutorial_complete()
        5:
            # Courage only: a direct leader hit (target_index < 0) while
            # Face It Head-On is on the board earns the first Progress counter.
            if selected_class == "Courage" and tutorial_step == 1 and target_index < 0:
                print("TUTORIAL[L5,Courage,S1]: leader hit → complete")
                _tutorial_advance("Face It Head-On gained its first Recovery Progress! Attack the leader 3 times total to evolve it into Unbreakable Resolve. Lesson complete.")
                await get_tree().create_timer(1.2).timeout
                _tutorial_complete()

func _tutorial_on_follower_lost(player_side: bool) -> void:
    if not tutorial_mode or not player_side: return
    print("TUTORIAL[L%d,S%d]: follower_lost player_side=%s" % [tutorial_lesson, tutorial_step, str(player_side)])
    if tutorial_lesson == 5 and tutorial_step == 0:
        print("TUTORIAL[L5,S0]: follower entered Relapse Zone → step→1, waiting for revive")
        _tutorial_advance("Your follower was defeated and sent to the Relapse Zone. Play Recovery Call from your hand to bring it back.")
        tutorial_step = 1  # _tutorial_advance already set it to 1; explicit for clarity

func _tutorial_on_recovered(_player_side: bool) -> void:
    if not tutorial_mode: return
    # Revive completion is handled in _tutorial_on_card_played for the revive ability card
    pass

func _run_tutorial_enemy_turn() -> void:
    await get_tree().create_timer(0.55).timeout
    if game_over: return
    print("TUTORIAL[L%d,S%d]: enemy_turn starting (player_board=%d enemy_board=%d)" % [tutorial_lesson, tutorial_step, player_board.size(), enemy_board.size()])
    # Lesson 5: enemy attacks the player's first follower to kill it,
    # demonstrating the Relapse Zone for the Recovery lesson.
    if tutorial_lesson == 5 and tutorial_step == 0:
        if selected_class != "Hope" and not selected_class.is_empty():
            # Non-Hope classes don't need the enemy to attack to set up their
            # lesson — the enemy simply passes so the player can act freely.
            safe_set_text(status_label, "Opponent passes — your turn.")
            await get_tree().create_timer(0.4).timeout
        else:
            # Hope path: the enemy destroys the player's follower so it enters
            # the Relapse Zone, setting up the Recovery Call revive demo.
            safe_set_text(status_label, "Opponent's turn — your follower is under attack!")
            if not enemy_board.is_empty() and not player_board.is_empty():
                var target_index := -1
                for i in range(player_board.size()):
                    if not bool(player_board[i].get("is_amulet", false)):
                        target_index = i; break
                if target_index >= 0:
                    await animate_enemy_attack(0, target_index)
                    await get_tree().create_timer(0.3).timeout
    else:
        safe_set_text(status_label, "Opponent passes — your turn.")
        await get_tree().create_timer(0.4).timeout

# main.gd and menu.gd share one profile file (user://journeys_dawn_profile.cfg).
# Several functions here only set a handful of keys before saving it straight
# back (match rewards, class-training completion). ConfigFile.save() writes
# out only what's currently loaded in memory, so if load() fails on a file
# that actually exists -- corrupted or partially written, most often from the
# app being killed mid-save on mobile -- saving anyway would silently erase
# every other saved field, including academy.complete, and send the player
# back into the tutorial on every future match with no way out. Use this
# instead of "ConfigFile.new(); cfg.load(...)" at any such partial-write site.
# Returns null when it's unsafe to save; a genuinely missing file (first run,
# before any profile has ever been saved) is still fine to proceed with
# defaults.
func _load_shared_profile_cfg_for_partial_write() -> ConfigFile:
    var cfg := ConfigFile.new()
    var err := cfg.load("user://journeys_dawn_profile.cfg")
    if err != OK and FileAccess.file_exists("user://journeys_dawn_profile.cfg"):
        return null
    return cfg

func complete_class_training() -> void:
    if not training_mode:
        return
    var cfg := _load_shared_profile_cfg_for_partial_write()
    if cfg == null:
        return
    var already_complete := bool(cfg.get_value("academy", "class_%s_complete" % training_class.to_lower(), false))
    cfg.set_value("academy", "class_%s_complete" % training_class.to_lower(), true)
    cfg.set_value("profile", "class", training_class)
    cfg.set_value("deck", "class", training_class)
    if not already_complete:
        var gold := int(cfg.get_value("economy", "gold", 600))
        cfg.set_value("economy", "gold", gold + 500)
    cfg.save("user://journeys_dawn_profile.cfg")

func refresh_leader_hp_badge_colors() -> void:
    if is_instance_valid(enemy_health_label):
        var enemy_style: StyleBoxFlat = enemy_health_label.get_theme_stylebox("normal") as StyleBoxFlat
        if enemy_style: enemy_style.border_color = class_accent_color(enemy_class)
    if is_instance_valid(player_health_label):
        var player_style: StyleBoxFlat = player_health_label.get_theme_stylebox("normal") as StyleBoxFlat
        if player_style: player_style.border_color = class_accent_color(selected_class)

func start_game() -> void:
    refresh_battlefield_theme()
    refresh_leader_hp_badge_colors()
    signature_voice_played.clear()
    last_bark_at = -999.0
    player_low_health_barked = false
    enemy_low_health_barked = false
    player_walking_free_active = false
    enemy_walking_free_active = false
    game_over = false; busy = false; selected_attacker = -1; selected_evolution_cost = 0
    if training_mode:
        training_objective_index = 0
        training_resource_value = 0
        training_attacked_this_turn = false
        training_played_follower = false
        training_healed = false
        training_recovered = false
        training_played_skill = false
        training_spent_resource = false
        training_destroyed_enemy = false
        training_survived_combat = false
        training_progress_trigger_count = 0
    if tutorial_mode:
        tutorial_step = 0
    player_evolutions_used = [false, false, false, false]; enemy_evolutions_used = [false, false, false, false]
    player_health = STARTING_HEALTH; enemy_health = STARTING_HEALTH
    player_mana = 0; player_max_mana = 0; enemy_mana = 0; enemy_max_mana = 0; turn_number = 0
    player_momentum = 0; enemy_momentum = 0; momentum_used_this_turn = false
    player_courage_entered = 0; enemy_courage_entered = 0
    player_hand.clear(); enemy_hand.clear(); player_board.clear(); enemy_board.clear(); player_relapse.clear(); enemy_relapse.clear()
    phoenix_pending_player = false; phoenix_pending_enemy = false; phoenix_tier_player = 1; phoenix_tier_enemy = 1
    player_deck = prepare_balanced_draw_order(build_deck_for_mode(selected_class, player_deck_mode))
    enemy_deck = prepare_balanced_draw_order(build_deck_for_mode(enemy_class, enemy_deck_mode))
    for i in range(4):
        draw_card(player_deck, player_hand)
        draw_card(enemy_deck, enemy_hand)
    prepare_training_hand()
    player_goes_first = true if (training_mode or tutorial_mode) else randi() % 2 == 0
    if not hotseat_mode:
        if player_goes_first:
            enemy_momentum = 1
        else:
            player_momentum = 1
    else:
        active_player_number = 1
        hotseat_second_chance_stage = 1
    update_leaders()
    safe_set_text(status_label, "Opening hand — use your Second Chance wisely.")
    set_battle_music("battle_early_v2")
    play_class_battle_ambience()
    refresh_ui()
    show_second_chance()

func add_training_card_to_hand(card_data: Dictionary) -> void:
    if player_hand.size() >= MAX_HAND:
        player_hand.pop_back()
    player_hand.append(card_data)

func prepare_training_hand() -> void:
    if tutorial_mode:
        player_hand.clear()
        enemy_hand.clear()
        _setup_tutorial_lesson()
        return
    if not training_mode:
        return
    match training_class:
        "Courage":
            add_training_card_to_hand(_find_card_by_name(build_class_cards("Courage"), "Face It Head-On"))
            add_training_card_to_hand(card("Training Rookie", 1, 2, 3, "Courage", "Training", "none", 0, "A sturdy follower for learning Resolve.", "flame", "jd-132"))
            add_training_card_to_hand(card("Stand Your Ground", 2, 2, 4, "Courage", "Training", "guard", 0, "Protector. Survive combat to build Resolve.", "shield", "jd-133"))
        "Hope":
            add_training_card_to_hand(_find_card_by_name(build_class_cards("Hope"), "The Comeback Trail"))
            add_training_card_to_hand(card("Guiding Light", 1, 1, 2, "Hope", "Training", "heal_leader", 3, "Arrival: Restore 3 Defense.", "hands", "jd-134"))
            add_training_card_to_hand(card("Recovery Call", 3, 2, 3, "Hope", "Training", "revive", 0, "Arrival: Recover the most recent follower from your Relapse Zone.", "star", "jd-135"))
        "Serenity":
            add_training_card_to_hand(_find_card_by_name(build_class_cards("Serenity"), "Sanctuary of Serenity"))
            add_training_card_to_hand(card("Quiet Renewal", 2, 2, 3, "Serenity", "Training", "heal_leader", 3, "Arrival: Restore 3 Defense.", "hands", "jd-137"))
        _:
            add_training_card_to_hand(_find_card_by_name(build_class_cards("Purpose"), "Daily Progress"))
            add_training_card_to_hand(card("Walking Free", 10, 6, 8, "Purpose", "Platinum", "walking_free", 0, "Purpose Platinum. Reward for a completed Progress journey.", "star"))

func second_chance_momentum(card_count: int) -> int:
    if card_count <= 1:
        return 0
    if card_count <= 3:
        return 1
    return 2

# CardArt.resolve() and second_chance_card_art() removed.
# All art resolution goes through CardArt.resolve(cd) — the shared autoload.

# A framed portrait panel built from real card art, used by every evolution
# cinematic as the "hero art" instead of procedural ASCII/text shapes. Starts
# invisible/tiny — callers tween modulate:a and scale in themselves so each
# tier can time the reveal differently.
func build_art_medallion(texture: Texture2D, pos: Vector2, size: Vector2, border_color: Color, corner_radius: int = 16) -> Panel:
    var frame := Panel.new()
    frame.position = pos
    frame.size = size
    frame.pivot_offset = size * 0.5
    frame.modulate = Color(1, 1, 1, 0)
    frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var frame_style := StyleBoxFlat.new()
    frame_style.bg_color = Color(0.02, 0.03, 0.05, 0.98)
    frame_style.border_color = border_color
    frame_style.set_border_width_all(4)
    frame_style.set_corner_radius_all(corner_radius)
    frame_style.shadow_color = Color(0, 0, 0, 0.7)
    frame_style.shadow_size = 18
    frame.add_theme_stylebox_override("panel", frame_style)

    var art := TextureRect.new()
    art.texture = texture
    art.position = Vector2(6, 6)
    art.size = size - Vector2(12, 12)
    art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    art.clip_contents = true
    art.mouse_filter = Control.MOUSE_FILTER_IGNORE
    frame.add_child(art)
    return frame

# A radial burst of small glyph particles (reused/generalized from the
# existing victory-sequence sparkle burst) so Epic/Legendary/Platinum
# evolutions and the Sponsor cinematic all share one particle system instead
# of each hand-rolling its own.
func spawn_sparkle_burst(origin: Vector2, count: int, colors: Array, layer: Node, base_distance: float = 95.0) -> void:
    var glyphs := ["✦", "★", "•"]
    for i in range(count):
        var sparkle := Label.new()
        sparkle.text = glyphs[i % glyphs.size()]
        sparkle.add_theme_font_size_override("font_size", ui_font(16 + (i % 3) * 5))
        sparkle.add_theme_color_override("font_color", colors[i % colors.size()])
        sparkle.z_index = 1500
        sparkle.mouse_filter = Control.MOUSE_FILTER_IGNORE
        sparkle.position = origin
        layer.add_child(sparkle)
        var angle := TAU * float(i) / float(count) + randf_range(-0.12, 0.12)
        var distance := base_distance + float(i % 4) * 16.0
        var destination := sparkle.position + Vector2(cos(angle), sin(angle)) * distance
        var sparkle_tween := create_tween().set_parallel(true)
        sparkle_tween.tween_property(sparkle, "position", destination, 0.65)
        sparkle_tween.tween_property(sparkle, "modulate:a", 0.0, 0.65)
        sparkle_tween.tween_property(sparkle, "rotation", angle, 0.65)
        sparkle_tween.finished.connect(sparkle.queue_free)

func show_second_chance() -> void:
    if tutorial_mode:
        call_deferred("start_player_turn")
        return
    if is_instance_valid(second_chance_overlay):
        second_chance_overlay.queue_free()
    second_chance_selected.clear()
    second_chance_overlay = ColorRect.new()
    second_chance_overlay.color = Color(0.01, 0.02, 0.05, 0.96)
    second_chance_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    second_chance_overlay.z_index = 4000
    add_child(second_chance_overlay)

    var title := Label.new()
    title.text = "SECOND CHANCE"
    title.position = Vector2(315, 38)
    title.size = Vector2(650, 58)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", ui_font(38))
    title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.34))
    second_chance_overlay.add_child(title)

    var explanation := Label.new()
    explanation.text = "Tap cards to replace. A deeper Second Chance gives your opponent Momentum."
    explanation.position = Vector2(180, 100)
    explanation.size = Vector2(920, 44)
    explanation.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    explanation.add_theme_font_size_override("font_size", ui_font(19))
    second_chance_overlay.add_child(explanation)

    for i in range(player_hand.size()):
        var index := i
        var cd: Dictionary = player_hand[i]
        var b := Button.new()
        b.position = Vector2(185 + i * 230, 170)
        b.size = Vector2(205, 300)
        b.text = ""
        b.focus_mode = Control.FOCUS_NONE
        b.clip_contents = true
        b.custom_minimum_size = Vector2.ZERO
        var normal := StyleBoxFlat.new()
        normal.bg_color = Color(0.035, 0.065, 0.12, 0.99)
        normal.border_color = class_accent_color(selected_class)
        normal.set_border_width_all(3)
        normal.set_corner_radius_all(15)
        b.add_theme_stylebox_override("normal", normal)
        var hover := normal.duplicate() as StyleBoxFlat
        hover.border_color = Color(1.0,0.84,0.35)
        hover.set_border_width_all(5)
        b.add_theme_stylebox_override("hover", hover)

        # Render the same complete card used in battle so the mulligan shows
        # its artwork, name, rarity, stats, keywords, and full effect together.
        var rendered_data: Dictionary = cd.duplicate(true)
        if str(rendered_data.get("display_text", "")).is_empty():
            rendered_data["display_text"] = str(rendered_data.get("effect", rendered_data.get("text", "")))
        # PREVIEW mode: disables breathing scale, orbs, hover lift, and attack
        # transforms so every card renders at a stable, identical size.
        # Must be set BEFORE setup() so _build()/_init_rarity_vfx() reads it.
        var full_card := CardView.new()
        full_card.display_mode = CardView.DisplayMode.PREVIEW
        full_card.setup(rendered_data, index, false, false)
        full_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
        # Scale 1.58× fills the 205×300 slot exactly (142×1.58=224 clipped to
        # 205 wide; 186×1.58=294 clipped to 300 tall by clip_contents on slot).
        full_card.scale = Vector2(1.58, 1.58)
        full_card.pivot_offset = Vector2.ZERO
        full_card.position = Vector2((205.0 - 142.0 * 1.58) * 0.5, (300.0 - 186.0 * 1.58) * 0.5)
        b.add_child(full_card)

        b.pressed.connect(func():
            if not is_instance_valid(b):
                return
            if second_chance_selected.has(index):
                second_chance_selected.erase(index)
                b.modulate = Color.WHITE
            else:
                second_chance_selected.append(index)
                b.modulate = Color(0.55, 0.85, 1.0)
            update_second_chance_summary()
        )
        second_chance_overlay.add_child(b)

    var confirm := Button.new()
    confirm.name = "ConfirmSecondChance"
    confirm.position = Vector2(455, 555)
    confirm.size = Vector2(370, 72)
    confirm.text = "KEEP THIS HAND"
    confirm.add_theme_font_size_override("font_size", ui_font(22))
    confirm.pressed.connect(confirm_second_chance)
    second_chance_overlay.add_child(confirm)

    var summary := Label.new()
    summary.name = "SecondChanceSummary"
    summary.position = Vector2(260, 490)
    summary.size = Vector2(760, 50)
    summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    summary.add_theme_font_size_override("font_size", ui_font(18))
    second_chance_overlay.add_child(summary)
    update_second_chance_summary()

func update_second_chance_summary() -> void:
    if not is_instance_valid(second_chance_overlay):
        return
    var summary := second_chance_overlay.get_node_or_null("SecondChanceSummary") as Label
    var confirm := second_chance_overlay.get_node_or_null("ConfirmSecondChance") as Button
    var count := second_chance_selected.size()
    var granted := second_chance_momentum(count)
    safe_set_text(summary, "%d selected • Opponent gains %d Momentum" % [count, granted])
    safe_set_text(confirm, "KEEP THIS HAND" if count == 0 else "USE SECOND CHANCE")

func confirm_second_chance() -> void:
    if not is_instance_valid(second_chance_overlay):
        return
    second_chance_selected.sort()
    second_chance_selected.reverse()
    var returned: Array = []
    for index in second_chance_selected:
        if index >= 0 and index < player_hand.size():
            returned.append(player_hand.pop_at(index))
    enemy_momentum += second_chance_momentum(returned.size())
    for i in range(returned.size()):
        draw_card(player_deck, player_hand)
    for cd in returned:
        player_deck.push_front(cd)
    player_deck = prepare_balanced_draw_order(player_deck)
    play_sfx("revive")
    second_chance_overlay.queue_free()
    second_chance_selected.clear()
    refresh_ui()
    if online_mode:
        online_mulligan_complete=true
        NetworkManager.send_mulligan_done(serialize_online_state())
        busy=true; player_turn_active=false
        safe_set_text(status_label,"Second Chance locked in. Waiting for your opponent...")
        return
    if hotseat_mode and hotseat_second_chance_stage == 1:
        hotseat_second_chance_stage = 2
        swap_perspective()
        show_pass_device_overlay("PLAYER 2", "Your opening hand is ready. Take your Second Chance privately.", func(): show_second_chance())
        return
    if hotseat_mode:
        # Both players completed Second Chance. Return Player 1 to the lower side,
        # then begin with the randomly selected player.
        if active_player_number == 2:
            swap_perspective()
        active_player_number = 1
        if not player_goes_first:
            swap_perspective()
            active_player_number = 2
        show_pass_device_overlay("PLAYER %d" % active_player_number, "You take the first turn.", func(): start_player_turn())
        return
    safe_set_text(status_label, "Second Chance complete. %s takes the first turn." % ("You" if player_goes_first else "Opponent"))
    await get_tree().create_timer(0.35).timeout
    if player_goes_first:
        start_player_turn()
    else:
        busy = true
        await enemy_turn()

func activate_player_momentum() -> void:
    if not player_turn_active or game_over or busy or momentum_used_this_turn or player_momentum <= 0:
        return
    player_momentum -= 1
    momentum_used_this_turn = true
    player_mana = min(MAX_MANA + 1, player_mana + 1)
    play_sfx("evolve_cinematic")
    show_vfx("MOMENTUM +1 PP", Vector2(520, 545), Color(1.0, 0.78, 0.25))
    safe_set_text(status_label, "Momentum activated — +1 temporary Play Point this turn.")
    refresh_ui()
    send_online_snapshot()

func enemy_activate_momentum_if_helpful() -> void:
    if enemy_momentum <= 0:
        return
    for cd in enemy_hand:
        if int(cd.get("cost", 0)) == enemy_mana + 1:
            enemy_momentum -= 1
            enemy_mana += 1
            show_vfx("ENEMY MOMENTUM", Vector2(520, 105), Color(1.0, 0.56, 0.20))
            return

func draw_card(deck: Array, hand: Array) -> void:
    if deck.is_empty():
        return
    var drawn: Dictionary = deck.pop_back()
    if hand.size() >= MAX_HAND:
        deck.push_front(drawn)
        play_sfx("overdraw_revive")
        if is_instance_valid(status_label):
            status_label.text = "%s was Revived to the bottom of the deck — hand limit 9." % str(drawn.get("name", "Card"))
        if is_inside_tree():
            show_vfx("REVIVED", Vector2(550, 475 if hand == player_hand else 70), Color(0.55, 0.95, 1.0))
        return
    hand.append(drawn)
    play_sfx("draw")
    var draw_is_player: bool = (hand == player_hand)
    show_vfx("DRAW", Vector2(520, 490 if draw_is_player else 55), Color(0.72, 0.58, 1.0))

func start_player_turn() -> void:
    if game_over: return
    clear_daily_progress_temporary_buffs(true)
    busy = false; selected_attacker = -1; turn_number += 1; momentum_used_this_turn = false
    player_max_mana = min(MAX_MANA, player_max_mana + 1); player_mana = player_max_mana
    for unit in player_board:
        if bool(unit.get("skip_next_attack", false)):
            unit["can_attack"] = false
            unit["skip_next_attack"] = false
        else:
            unit["can_attack"] = true
        unit["evolved_this_turn"] = false
    if phoenix_pending_player and not game_over:
        phoenix_pending_player = false
        var t := phoenix_tier_player
        await get_tree().create_timer(0.35).timeout
        if follower_count(player_board) < MAX_BOARD:
            var phoenix := _make_phoenix_card(t)
            player_board.append(phoenix)
            refresh_ui(true, player_board.size() - 1, true)
            await show_vfx("PHOENIX RISES! %d/%d" % [t, t], area_center(true), Color(1.0, 0.72, 0.30))
        else:
            await show_vfx("PHOENIX CANNOT RETURN — BOARD FULL", area_center(true), Color(1.0, 0.25, 0.18))
    if not (turn_number == 1 and player_goes_first):
        draw_card(player_deck, player_hand)
    safe_set_text(status_label, "Your turn — play cards, attack, or spend Momentum.")
    reset_turn_timer()
    update_dynamic_music()
    refresh_ui()

func sponsor_in_play(board: Array) -> bool:
    for unit in board:
        if str(unit.get("ability", "")) == "sponsor" or bool(unit.get("is_sponsor", false)):
            return true
    return false

func _make_phoenix_card(tier: int) -> Dictionary:
    var phoenix := card("Phoenix Rising", 1, tier, tier, "Courage", "Legendary", "phoenix_rising", 0,
        "Destroyed: returns at the start of your next turn at +1/+1 (1/1 → 10/10). At 10/10, permanently falls.",
        "star", "jd-125")
    phoenix["phoenix_tier"] = tier
    phoenix["max_health"] = tier
    phoenix["can_attack"] = false
    phoenix["summoned_turn"] = turn_number
    return phoenix

func create_sponsee(player_side: bool) -> void:
    var board: Array = player_board if player_side else enemy_board
    if follower_count(board) >= MAX_BOARD or not sponsor_in_play(board):
        return
    var path := selected_class if player_side else enemy_class
    var token := card("Sponsee", 2, 3, 3, "Universal", "Token", "sponsee", 0, "Guided by %s." % path, "hands")
    token["is_sponsee"] = true
    token["sponsor_protection"] = true
    match path:
        "Courage":
            token["attack"] = 4
            token["can_attack"] = true
            token["display_text"] = "Courage Path: Charge. Legacy restores 2 Defense."
        "Hope":
            token["health"] = 5
            token["max_health"] = 5
            token["display_text"] = "Hope Path: Legacy restores 5 Defense."
        "Serenity":
            token["health"] = 5
            token["max_health"] = 5
            token["ability"] = "guard"
            token["display_text"] = "Serenity Path: Protector. Legacy restores 3 Defense."
        "Purpose":
            token["display_text"] = "Purpose Path: Gain 2 Progress when this enters play."
            add_progress(player_side, 2)
    board.append(token)
    await show_vfx("%s SPONSEE" % path.to_upper(), area_center(player_side), Color(1.0,0.82,0.34))

func clear_daily_progress_temporary_buffs(player_side: bool) -> void:
    var board: Array = player_board if player_side else enemy_board
    for ally in board:
        var temp_bonus := int(ally.get("daily_progress_temp_attack", 0))
        if temp_bonus > 0:
            ally["attack"] = maxi(0, int(ally.get("attack", 0)) - temp_bonus)
            ally["daily_progress_temp_attack"] = 0

func trigger_daily_progress_end_turn(player_side: bool) -> void:
    var board: Array = player_board if player_side else enemy_board
    var active: Dictionary = {}
    for unit in board:
        if str(unit.get("ability", "")) == "daily_progress":
            active = unit
            break
    if active.is_empty():
        return
    var remaining_pp := player_mana if player_side else enemy_mana
    if remaining_pp != 0:
        return
    var rebuilt := player_life_rebuilt if player_side else enemy_life_rebuilt
    if rebuilt:
        draw_card(player_deck if player_side else enemy_deck, player_hand if player_side else enemy_hand)
        for ally in board:
            if bool(ally.get("is_amulet", false)):
                continue
            ally["attack"] = int(ally.get("attack", 0)) + 1
            ally["daily_progress_temp_attack"] = int(ally.get("daily_progress_temp_attack", 0)) + 1
        await show_vfx("A LIFE REBUILT — DRAW + BOARD POWER", area_center(player_side), Color(1.0, 0.84, 0.34))
        return
    add_progress(player_side, 1)
    for ally in board:
        if bool(ally.get("is_amulet", false)):
            continue
        ally["attack"] = int(ally.get("attack", 0)) + 1
        ally["daily_progress_temp_attack"] = int(ally.get("daily_progress_temp_attack", 0)) + 1
    var counters := player_progress_counters if player_side else enemy_progress_counters
    var three_done := player_daily_progress_three_triggered if player_side else enemy_daily_progress_three_triggered
    if counters >= 3 and not three_done:
        if player_side:
            player_daily_progress_three_triggered = true
            player_max_mana = mini(MAX_MANA, player_max_mana + 1)
        else:
            enemy_daily_progress_three_triggered = true
            enemy_max_mana = mini(MAX_MANA, enemy_max_mana + 1)
        for ally in board:
            if bool(ally.get("is_amulet", false)):
                continue
            ally["attack"] = int(ally.get("attack", 0)) + 1
            ally["health"] = int(ally.get("health", 0)) + 1
            ally["max_health"] = int(ally.get("max_health", ally.get("health", 0))) + 1
        await show_vfx("3 PROGRESS — +1 MAX PP, ALLIES +1/+1", area_center(player_side), Color(0.55, 0.88, 1.0))
    if counters >= 6:
        if player_side:
            player_life_rebuilt = true
        else:
            enemy_life_rebuilt = true
        active["name"] = "A Life Rebuilt"
        active["display_text"] = "End a turn with 0 PP: Draw a card and give allied followers +1 Attack until your next turn."
        await show_vfx("A LIFE REBUILT", area_center(player_side), Color(1.0, 0.84, 0.34))

func apply_sanctuary_serenity_buff(player_side: bool) -> void:
    var board: Array = player_board if player_side else enemy_board
    var has_sanctuary := false
    for unit in board:
        if str(unit.get("ability", "")) == "sanctuary_serenity":
            has_sanctuary = true
            break
    if not has_sanctuary:
        return
    var area_sct: Control = player_board_area if player_side else enemy_board_area
    for i in range(board.size()):
        var ally: Dictionary = board[i]
        if bool(ally.get("is_amulet", false)):
            continue
        ally["attack"] = int(ally.get("attack", 0)) + 1
        ally["health"] = int(ally.get("health", 0)) + 1
        ally["max_health"] = int(ally.get("max_health", ally.get("health", 0))) + 1
        show_buff_flash(find_card_view_for_board_index(area_sct, i), "+1/+1", Color(0.55, 0.9, 1.0))
        await show_vfx("SANCTUARY — ALLY +1/+1", area_center(player_side), Color(0.55, 0.9, 1.0))
        return

func trigger_leader_recovery_progress(player_side: bool, ability: String) -> void:
    var board: Array = player_board if player_side else enemy_board
    var active: Dictionary = {}
    for unit in board:
        if str(unit.get("ability", "")) == ability:
            active = unit
            break
    if active.is_empty():
        return
    var evolved: bool = (player_courage_recovery_evolved if player_side else enemy_courage_recovery_evolved) if ability == "standing_ground" else (player_hope_recovery_evolved if player_side else enemy_hope_recovery_evolved)
    var milestone_done: bool = (player_courage_recovery_milestone if player_side else enemy_courage_recovery_milestone) if ability == "standing_ground" else (player_hope_recovery_milestone if player_side else enemy_hope_recovery_milestone)
    if evolved:
        if ability == "standing_ground":
            for ally in board:
                if bool(ally.get("is_amulet", false)): continue
                ally["attack"] = int(ally.get("attack", 0)) + 1
                ally["daily_progress_temp_attack"] = int(ally.get("daily_progress_temp_attack", 0)) + 1
            await show_vfx("UNBREAKABLE RESOLVE — ALLIES +1 ATTACK", area_center(player_side), Color(1.0, 0.42, 0.2))
        else:
            if player_side: player_health = mini(STARTING_HEALTH, player_health + 2)
            else: enemy_health = mini(STARTING_HEALTH, enemy_health + 2)
            await show_vfx("RENEWED HOPE — RESTORE 2", area_center(player_side), Color(1.0, 0.85, 0.5))
        return
    add_progress(player_side, 1)
    var counters := player_progress_counters if player_side else enemy_progress_counters
    if counters >= 3 and not milestone_done:
        if ability == "standing_ground":
            if player_side: player_courage_recovery_milestone = true
            else: enemy_courage_recovery_milestone = true
            for ally in board:
                if bool(ally.get("is_amulet", false)): continue
                ally["attack"] = int(ally.get("attack", 0)) + 1
            await show_vfx("3 PROGRESS — ALLIES +1 ATTACK", area_center(player_side), Color(1.0, 0.55, 0.25))
        else:
            if player_side: player_hope_recovery_milestone = true
            else: enemy_hope_recovery_milestone = true
            if player_side: player_health = mini(STARTING_HEALTH, player_health + 3)
            else: enemy_health = mini(STARTING_HEALTH, enemy_health + 3)
            for ally in board:
                if bool(ally.get("is_amulet", false)): continue
                ally["health"] = int(ally.get("health", 0)) + 1
                ally["max_health"] = int(ally.get("max_health", ally.get("health", 0))) + 1
                break
            await show_vfx("3 PROGRESS — RESTORE 3 + ALLY +1/+1", area_center(player_side), Color(1.0, 0.85, 0.62))
    if counters >= 6:
        if ability == "standing_ground":
            if player_side: player_courage_recovery_evolved = true
            else: enemy_courage_recovery_evolved = true
            active["name"] = "Unbreakable Resolve"
            active["display_text"] = "Amulet — Whenever you attack the enemy leader directly, give all allies +1 Attack until your next turn."
            await show_vfx("UNBREAKABLE RESOLVE", area_center(player_side), Color(1.0, 0.42, 0.2))
        else:
            if player_side: player_hope_recovery_evolved = true
            else: enemy_hope_recovery_evolved = true
            active["name"] = "Renewed Hope"
            active["display_text"] = "Amulet — Whenever you recover a card from the Relapse Zone, restore 2 Defense."
            await show_vfx("RENEWED HOPE", area_center(player_side), Color(1.0, 0.85, 0.5))

func trigger_calm_heal(player_side: bool) -> void:
    var attacked := player_attacked_this_turn if player_side else enemy_attacked_this_turn
    if attacked:
        return
    var board: Array = player_board if player_side else enemy_board
    var active: Dictionary = {}
    for unit in board:
        if str(unit.get("ability", "")) == "calm_heal":
            active = unit
            break
    if active.is_empty():
        return
    var amount := maxi(1, int(active.get("amount", 1)))
    if player_side: player_health = mini(STARTING_HEALTH, player_health + amount)
    else: enemy_health = mini(STARTING_HEALTH, enemy_health + amount)
    await apply_sanctuary_serenity_buff(player_side)
    await show_vfx("CALM — RESTORE %d" % amount, area_center(player_side), Color(0.4, 1.0, 0.7))

func sponsor_end_turn(player_side: bool) -> void:
    var board: Array = player_board if player_side else enemy_board
    if sponsor_in_play(board) and follower_count(board) < MAX_BOARD:
        await create_sponsee(player_side)

func end_player_turn() -> void:
    if game_over or busy: return
    training_on_end_turn()
    _tutorial_on_end_turn()
    await trigger_calm_heal(true)
    player_attacked_this_turn = false
    await trigger_daily_progress_end_turn(true)
    await sponsor_end_turn(true)
    player_turn_active = false
    if is_instance_valid(slacking_popup):
        slacking_popup.queue_free()
    busy = true
    selected_attacker = -1
    selected_evolution_cost = 0
    if is_instance_valid(end_turn_button):
        safe_set_disabled(end_turn_button, true)
    if online_mode:
        await send_online_snapshot("end_turn")
        safe_set_text(status_label,"Opponent's turn...")
        refresh_ui()
        return
    if hotseat_mode:
        swap_perspective()
        active_player_number = 2 if active_player_number == 1 else 1
        show_pass_device_overlay("PLAYER %d" % active_player_number, "Pass the device. Your hand stays hidden until you continue.", func(): start_player_turn())
        return
    safe_set_text(status_label, "Opponent's turn...")
    refresh_ui()
    await get_tree().create_timer(0.45).timeout
    await enemy_turn()

func swap_perspective() -> void:
    var tmp_array: Array
    tmp_array = player_deck; player_deck = enemy_deck; enemy_deck = tmp_array
    tmp_array = player_hand; player_hand = enemy_hand; enemy_hand = tmp_array
    tmp_array = player_board; player_board = enemy_board; enemy_board = tmp_array
    tmp_array = player_relapse; player_relapse = enemy_relapse; enemy_relapse = tmp_array
    var tmp_int := player_health; player_health = enemy_health; enemy_health = tmp_int
    tmp_int = player_mana; player_mana = enemy_mana; enemy_mana = tmp_int
    tmp_int = player_max_mana; player_max_mana = enemy_max_mana; enemy_max_mana = tmp_int
    tmp_int = player_momentum; player_momentum = enemy_momentum; enemy_momentum = tmp_int
    var tmp_bool_array: Array[bool] = player_evolutions_used; player_evolutions_used = enemy_evolutions_used; enemy_evolutions_used = tmp_bool_array
    var tmp_class := selected_class; selected_class = enemy_class; enemy_class = tmp_class
    update_leaders()
    refresh_ui()

func show_pass_device_overlay(title_text: String, message: String, callback: Callable) -> void:
    busy = true
    player_turn_active = false
    overlay.visible = true
    for child in overlay.get_children(): child.queue_free()
    var panel := Panel.new(); panel.position=Vector2(325,150); panel.size=Vector2(630,420)
    var st := StyleBoxFlat.new(); st.bg_color=Color(0.015,0.03,0.065,0.985); st.border_color=Color(0.96,0.78,0.30); st.set_border_width_all(4); st.set_corner_radius_all(24); st.shadow_color=Color(0,0,0,0.8); st.shadow_size=18
    panel.add_theme_stylebox_override("panel",st); overlay.add_child(panel)
    var title := Label.new(); title.text=title_text; title.position=Vector2(45,55); title.size=Vector2(540,70); title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; title.add_theme_font_size_override("font_size",ui_font(42)); title.add_theme_color_override("font_color",Color(1.0,0.82,0.34)); panel.add_child(title)
    var msg := Label.new(); msg.text=message; msg.position=Vector2(75,150); msg.size=Vector2(480,95); msg.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; msg.vertical_alignment=VERTICAL_ALIGNMENT_CENTER; msg.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; msg.add_theme_font_size_override("font_size",ui_font(22)); panel.add_child(msg)
    var ready := Button.new(); ready.text="I'M READY"; ready.position=Vector2(175,290); ready.size=Vector2(280,72); ready.add_theme_font_size_override("font_size",ui_font(24)); ready.pressed.connect(func(): overlay.visible=false; busy=false; callback.call()); panel.add_child(ready)

func enemy_turn() -> void:
    if tutorial_mode:
        await _run_tutorial_enemy_turn()
        if not game_over:
            start_player_turn()
        return
    clear_daily_progress_temporary_buffs(false)
    if phoenix_pending_enemy and not game_over:
        phoenix_pending_enemy = false
        var t := phoenix_tier_enemy
        await get_tree().create_timer(0.35).timeout
        if follower_count(enemy_board) < MAX_BOARD:
            var phoenix := _make_phoenix_card(t)
            phoenix["can_attack"] = false
            enemy_board.append(phoenix)
            refresh_ui(true, -1, false)
            await show_vfx("PHOENIX RISES! %d/%d" % [t, t], area_center(false), Color(1.0, 0.72, 0.30))
        else:
            await show_vfx("PHOENIX CANNOT RETURN — BOARD FULL", area_center(false), Color(1.0, 0.25, 0.18))
    enemy_max_mana = min(MAX_MANA, enemy_max_mana + 1); enemy_mana = enemy_max_mana
    if not (turn_number == 0 and not player_goes_first):
        draw_card(enemy_deck, enemy_hand)
    enemy_activate_momentum_if_helpful()
    for unit in enemy_board:
        if bool(unit.get("skip_next_attack", false)):
            unit["can_attack"] = false
            unit["skip_next_attack"] = false
        else:
            unit["can_attack"] = true
        unit["evolved_this_turn"] = false
    while true:
        var best := -1
        var affordable: Array = []
        for i in range(enemy_hand.size()):
            var candidate: Dictionary = enemy_hand[i]
            var can_fit := bool(candidate.get("is_spell", false)) or follower_count(enemy_board) < MAX_BOARD
            if can_fit and int(candidate["cost"]) <= enemy_mana:
                affordable.append(i)
                if best == -1 or int(candidate["cost"]) > int(enemy_hand[best]["cost"]): best = i
        if best == -1: break
        if practice_mode:
            # A beginner opponent doesn't optimize its curve: sometimes it
            # leaves mana on the table for the rest of the turn, and when it
            # does play, it isn't always the best/most expensive option.
            if randf() < PRACTICE_MISPLAY_CHANCE:
                break
            best = affordable[randi() % affordable.size()]
        var unit: Dictionary = enemy_hand.pop_at(best)
        enemy_mana -= int(unit["cost"])
        if bool(unit.get("is_spell", false)):
            await resolve_spell(unit, false)
            enemy_relapse.append(unit)
            refresh_ui()
            await get_tree().create_timer(0.28).timeout
            continue
        unit["can_attack"] = unit["ability"] in ["charge", "charge_storm"]
        unit["summoned_turn"] = turn_number
        if str(unit.get("faction", "")) == "Courage":
            enemy_courage_entered += 1
            if has_evolved_rise_together(enemy_board):
                unit["can_attack"] = true
                unit["determination_from_rise"] = true
        enemy_board.append(unit)
        refresh_ui(true, enemy_board.size() - 1, false)
        play_battle_bark(enemy_leader, enemy_class, "play", false)
        await get_tree().create_timer(0.38).timeout
        await resolve_on_play(unit, false)
    await enemy_use_evolution()
    var attackers := enemy_board.duplicate()
    for attacker in attackers:
        if game_over: return
        if not enemy_board.has(attacker) or bool(attacker.get("is_amulet", false)) or not bool(attacker.get("can_attack", false)): continue
        var target_index := first_guard_index(player_board)
        if target_index < 0:
            for candidate_index in range(player_board.size()):
                if not bool(player_board[candidate_index].get("is_amulet", false)):
                    var candidate_text := (str(player_board[candidate_index].get("text", "")) + " " + str(player_board[candidate_index].get("display_text", ""))).to_lower()
                    if not ("cannot be attacked" in candidate_text):
                        target_index = candidate_index
                        break
        var attacker_text := (str(attacker.get("text", "")) + " " + str(attacker.get("display_text", "")) + " " + str(attacker.get("ability", ""))).to_lower()
        if target_index < 0 and bool(attacker.get("evolved_this_turn", false)) and not ("breakthrough" in attacker_text or "storm" in attacker_text):
            continue
        if practice_mode and randf() < PRACTICE_SKIP_ATTACK_CHANCE:
            continue
        await animate_enemy_attack(enemy_board.find(attacker), target_index)
        if game_over: return
        await get_tree().create_timer(0.22).timeout
    await trigger_calm_heal(false)
    enemy_attacked_this_turn = false
    await trigger_daily_progress_end_turn(false)
    await sponsor_end_turn(false)
    start_player_turn()

func enemy_use_evolution() -> void:
    if enemy_board.is_empty():
        return
    if turn_number < 4:
        return
    var chosen_cost: int = 0
    for cost in [4, 3, 2, 1]:
        if enemy_mana >= cost and not enemy_evolutions_used[cost - 1]:
            chosen_cost = cost
            break
    if chosen_cost == 0:
        return
    if practice_mode and randf() < PRACTICE_SKIP_EVOLVE_CHANCE:
        return
    var target_index: int = -1
    var best_attack: int = -1
    for i in range(enemy_board.size()):
        if bool(enemy_board[i].get("evolved", false)) or bool(enemy_board[i].get("is_amulet", false)):
            continue
        var current_attack: int = int(enemy_board[i].get("attack", 0))
        if current_attack > best_attack:
            best_attack = current_attack
            target_index = i
    if target_index >= 0:
        await evolve_follower(target_index, chosen_cost, false)
        await get_tree().create_timer(0.25).timeout

func play_card(index: int) -> void:
    if game_over or busy or not player_turn_active or index < 0 or index >= player_hand.size(): return
    var chosen: Dictionary = player_hand[index]
    if follower_count(player_board) >= MAX_BOARD and not bool(chosen.get("is_spell", false)) and not bool(chosen.get("is_amulet", false)):
        status_label.text = "Your board is full."
        return
    if int(chosen["cost"]) > player_mana: status_label.text = "You need %d mana for %s." % [chosen["cost"], chosen["name"]]; return
    busy = true; player_mana -= int(chosen["cost"]); chosen = player_hand.pop_at(index)
    if bool(chosen.get("is_spell", false)):
        play_sfx("play")
        await resolve_spell(chosen, true)
        player_relapse.append(chosen)
        training_on_card_played(chosen)
        busy = false
        refresh_ui()
        send_online_snapshot()
        return
    chosen["can_attack"] = chosen["ability"] in ["charge", "charge_storm", "rush"]
    chosen["summoned_turn"] = turn_number
    if str(chosen.get("faction", "")) == "Courage":
        player_courage_entered += 1
        if has_evolved_rise_together(player_board):
            chosen["can_attack"] = true
            chosen["determination_from_rise"] = true
        for ally in player_board:
            if str(ally.get("ability", "")) == "rally_the_free" and bool(ally.get("evolved", false)):
                chosen["can_attack"] = true
                chosen["rush_from_rally"] = true
                break
    elif str(chosen.get("faction", "")) == "Purpose" and player_walking_free_active:
        chosen["can_attack"] = true
        chosen["rush_from_walking_free"] = true
    player_board.append(chosen); status_label.text = "%s enters the field!" % chosen["name"]
    play_sfx("platinum" if str(chosen.get("rarity", "")) == "Platinum" else "play")
    refresh_ui(true, player_board.size() - 1, true)
    play_battle_bark(player_leader, selected_class, "play", true)
    await get_tree().create_timer(0.34).timeout; await resolve_on_play(chosen, true)
    training_on_card_played(chosen)
    busy = false; refresh_ui(); send_online_snapshot()

func resolve_spell(spell: Dictionary, player_side: bool) -> void:
    var ability := str(spell.get("ability", ""))
    if ability == "second_chance":
        var foes: Array = enemy_board if player_side else player_board
        var ranked: Array = []
        for i in range(foes.size()):
            if not bool(foes[i].get("is_amulet", false)):
                ranked.append({"index": i, "attack": int(foes[i].get("attack", 0))})
        ranked.sort_custom(func(a, b): return int(a["attack"]) > int(b["attack"]))
        var targets: Array = []
        for entry in ranked.slice(0, mini(3, ranked.size())):
            targets.append(int(entry["index"]))
        for target_index in targets:
            var newcomer := card("Newcomer", 1, 1, 1, "Universal", "Bronze", "", 0, "A transformed 1/1 Newcomer.", "road")
            newcomer["can_attack"] = false
            newcomer["summoned_turn"] = turn_number
            foes[target_index] = newcomer
        if player_side:
            player_health = min(STARTING_HEALTH, player_health + 3)
        else:
            enemy_health = min(STARTING_HEALTH, enemy_health + 3)
        await show_vfx("SECOND CHANCE — 3 THREATS REDEEMED", area_center(not player_side), Color(1.0, 0.86, 0.35))
    elif ability == "strategic_collapse":
        var choice := 0
        if player_side:
            choice = await request_strategic_collapse_choice()
        else:
            choice = choose_strategic_collapse_ai()
        var foes: Array = enemy_board if player_side else player_board
        if choice == 0:
            for i in range(foes.size() - 1, -1, -1):
                if bool(foes[i].get("is_amulet", false)):
                    continue
                foes[i]["health"] = int(foes[i].get("health", 0)) - 5
                if int(foes[i].get("health", 0)) <= 0:
                    await destroy_unit(foes, i, not player_side)
            await show_vfx("STRATEGIC COLLAPSE — 5 DAMAGE", area_center(not player_side), Color(0.38, 0.7, 1.0))
        else:
            for i in range(foes.size() - 1, -1, -1):
                if bool(foes[i].get("is_amulet", false)):
                    continue
                if int(foes[i].get("attack", 0)) <= 5:
                    return_unit_to_hand(foes, i, not player_side)
            await show_vfx("STRATEGIC COLLAPSE — BOARD RETURNED", area_center(not player_side), Color(0.45, 0.82, 1.0))
        draw_card(player_deck if player_side else enemy_deck, player_hand if player_side else enemy_hand)
    elif ability == "calm_after_storm":
        var destroyed := 0
        destroyed += await destroy_all_followers_on_side(player_board, true)
        destroyed += await destroy_all_followers_on_side(enemy_board, false)
        if player_side:
            player_health = min(STARTING_HEALTH, player_health + 6)
        else:
            enemy_health = min(STARTING_HEALTH, enemy_health + 6)
        if destroyed >= 5:
            for _i in range(2):
                draw_card(player_deck if player_side else enemy_deck, player_hand if player_side else enemy_hand)
        await show_vfx("CALM AFTER THE STORM — %d FOLLOWERS CLEARED" % destroyed, Vector2(640, 350), Color(0.58, 0.9, 1.0))
    refresh_ui()

func destroy_all_followers_on_side(board: Array, owner_player_side: bool) -> int:
    var count := 0
    for i in range(board.size() - 1, -1, -1):
        if bool(board[i].get("is_amulet", false)):
            continue
        count += 1
        await destroy_unit(board, i, owner_player_side)
    return count

func choose_strategic_collapse_ai() -> int:
    var damage_score := 0
    var bounce_score := 0
    for unit in player_board:
        if bool(unit.get("is_amulet", false)):
            continue
        if int(unit.get("health", 0)) <= 5:
            damage_score += 1
        if int(unit.get("attack", 0)) <= 5:
            bounce_score += 1
    return 1 if bounce_score > damage_score else 0

func request_strategic_collapse_choice() -> int:
    spell_choice_result = -1
    overlay.visible = true
    for child in overlay.get_children():
        child.queue_free()
    var panel := Panel.new()
    panel.position = Vector2(310, 175)
    panel.size = Vector2(660, 360)
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.02, 0.04, 0.09, 0.98)
    style.border_color = Color(0.35, 0.72, 1.0)
    style.set_border_width_all(4)
    style.set_corner_radius_all(22)
    panel.add_theme_stylebox_override("panel", style)
    overlay.add_child(panel)
    var title := Label.new()
    title.text = "STRATEGIC COLLAPSE — CHOOSE ONE"
    title.position = Vector2(40, 35)
    title.size = Vector2(580, 50)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", ui_font(28))
    panel.add_child(title)
    var damage := Button.new()
    damage.text = "DEAL 5 TO ALL ENEMY FOLLOWERS"
    damage.position = Vector2(70, 115)
    damage.size = Vector2(520, 70)
    damage.pressed.connect(func(): spell_choice_result = 0)
    panel.add_child(damage)
    var bounce := Button.new()
    bounce.text = "RETURN ENEMIES WITH 5 OR LESS ATTACK"
    bounce.position = Vector2(70, 215)
    bounce.size = Vector2(520, 70)
    bounce.pressed.connect(func(): spell_choice_result = 1)
    panel.add_child(bounce)
    while spell_choice_result < 0:
        await get_tree().process_frame
    overlay.visible = false
    return spell_choice_result

func resolve_on_play(unit: Dictionary, player_side: bool) -> void:
    var ability := str(unit.get("ability", "")); var amount := int(unit.get("amount", 0))
    if ability in ["walking_free", "rally_the_free", "hope_platinum", "serenity_platinum"]:
        await play_signature_voice(str(unit.get("name", "")), player_side, false)
        await free_evolve_signature(unit, player_side)
    if ability == "heal_leader":
        if player_side: player_health = min(STARTING_HEALTH, player_health + amount)
        else: enemy_health = min(STARTING_HEALTH, enemy_health + amount)
        leader_feedback(player_leader if player_side else enemy_leader, amount, true)
        await show_vfx("+%d" % amount, player_leader.global_position if player_side else enemy_leader.global_position, Color(0.4, 1.0, 0.55))
    elif ability == "heal_leader_draw":
        if player_side: player_health = min(STARTING_HEALTH, player_health + amount)
        else: enemy_health = min(STARTING_HEALTH, enemy_health + amount)
        leader_feedback(player_leader if player_side else enemy_leader, amount, true)
        draw_card(player_deck if player_side else enemy_deck, player_hand if player_side else enemy_hand)
        await show_vfx("+%d + DRAW" % amount, player_leader.global_position if player_side else enemy_leader.global_position, Color(0.4, 1.0, 0.55))
    elif ability == "draw":
        draw_card(player_deck if player_side else enemy_deck, player_hand if player_side else enemy_hand); await show_vfx("DRAW", Vector2(550, 475 if player_side else 70), Color(0.55, 0.85, 1.0))
    elif ability == "damage_enemy":
        if player_side: enemy_health -= amount
        else: player_health -= amount
        leader_feedback(enemy_leader if player_side else player_leader, amount, false)
        await show_vfx("-%d" % amount, enemy_leader.global_position if player_side else player_leader.global_position, Color(1.0, 0.28, 0.2)); check_winner()
    elif ability == "buff_random":
        var board: Array = player_board if player_side else enemy_board
        for ally in board:
            if ally != unit:
                ally["attack"] += amount; ally["health"] += amount; ally["max_health"] += amount
                await show_vfx("+%d/+%d" % [amount, amount], Vector2(590, 360 if player_side else 175), Color(1.0, 0.85, 0.3)); break
    elif ability == "sponsor":
        var board: Array = player_board if player_side else enemy_board
        var sponsor_index: int = board.find(unit)
        if sponsor_index >= 0:
            unit["is_sponsor"] = true
            board[sponsor_index] = unit
        await play_sponsor_evolution_animation(unit, player_side)
        await create_sponsee(player_side)
        await create_sponsee(player_side)
    elif ability == "rise_together":
        var courage_count := player_courage_entered if player_side else enemy_courage_entered
        var board: Array = player_board if player_side else enemy_board
        var unit_index := board.find(unit)
        if courage_count >= 3 and unit_index >= 0 and not bool(unit.get("evolved", false)):
            await show_vfx("THE COURAGE OF MANY", area_center(player_side), Color(1.0, 0.72, 0.20))
            await free_evolve_rise_together(unit_index, player_side)
        else:
            await show_vfx("%d / 3 COURAGE" % courage_count, area_center(player_side), Color(0.95, 0.68, 0.28))
    elif ability == "first_step":
        draw_card(player_deck if player_side else enemy_deck, player_hand if player_side else enemy_hand)
        var own_max := player_max_mana if player_side else enemy_max_mana
        var foe_max := enemy_max_mana if player_side else player_max_mana
        if own_max < foe_max:
            if player_side: player_mana += 1
            else: enemy_mana += 1
            await show_vfx("FIRST STEP +1 PP", area_center(player_side), Color(0.55, 0.85, 1.0))
    elif ability == "daily_reflection":
        draw_card(player_deck if player_side else enemy_deck, player_hand if player_side else enemy_hand)
        var remaining := player_mana if player_side else enemy_mana
        if remaining == 0:
            if player_side: player_pending_temp_pp += 1
            else: enemy_pending_temp_pp += 1
            await show_vfx("REFLECTION: +1 PP NEXT TURN", area_center(player_side), Color(0.75, 0.70, 1.0))
    elif ability == "progress_counter":
        add_progress(player_side, amount)
        if (player_progress_counters if player_side else enemy_progress_counters) >= 3:
            draw_card(player_deck if player_side else enemy_deck, player_hand if player_side else enemy_hand)
            if player_side: player_progress_counters -= 3
            else: enemy_progress_counters -= 3
            await show_vfx("MILESTONE: DRAW", area_center(player_side), Color(0.95, 0.82, 0.35))
    elif ability == "sponsors_guidance":
        var gained := (player_max_mana if player_side else enemy_max_mana) > turn_number
        if gained:
            var allies: Array = player_board if player_side else enemy_board
            var area_sg: Control = player_board_area if player_side else enemy_board_area
            for i in range(allies.size()):
                var ally: Dictionary = allies[i]
                if ally == unit: continue
                ally["attack"] = int(ally.get("attack", 0)) + 1
                ally["health"] = int(ally.get("health", 0)) + 1
                ally["max_health"] = int(ally.get("max_health", ally.get("health", 0))) + 1
                show_buff_flash(find_card_view_for_board_index(area_sg, i), "+1/+1", Color(0.85, 0.72, 1.0))
                break
            await show_vfx("GUIDANCE +1/+1", area_center(player_side), Color(0.85, 0.72, 1.0))
    elif ability == "small_steps":
        draw_card(player_deck if player_side else enemy_deck, player_hand if player_side else enemy_hand)
        if (player_mana if player_side else enemy_mana) == 0:
            if player_side: player_health = min(STARTING_HEALTH, player_health + amount)
            else: enemy_health = min(STARTING_HEALTH, enemy_health + amount)
            await show_vfx("SMALL STEPS: RESTORE %d" % amount, area_center(player_side), Color(0.45, 1.0, 0.65))
    elif ability == "daily_progress":
        unit["is_amulet"] = true
        unit["can_attack"] = false
        unit["attack"] = 0
        unit["health"] = 0
        unit["max_health"] = 0
        unit["display_text"] = "Amulet — remains in play. Cannot be attacked or damaged; only Amulet-targeting effects can remove it. End with 0 PP to gain Progress."
        add_progress(player_side, amount)
        await show_vfx("DAILY PROGRESS", area_center(player_side), Color(0.70, 0.88, 1.0))
    elif ability == "finding_purpose":
        if player_side:
            player_max_mana = mini(MAX_MANA, player_max_mana + amount)
            player_mana = mini(player_max_mana, player_mana + amount)
        else:
            enemy_max_mana = mini(MAX_MANA, enemy_max_mana + amount)
            enemy_mana = mini(enemy_max_mana, enemy_mana + amount)
        await trigger_progress_growth(player_side)
        await show_vfx("FINDING PURPOSE: +1 MAX PP", area_center(player_side), Color(0.65, 0.82, 1.0))
    elif ability == "ramp" or ability == "ramp_draw":
        if player_side:
            player_max_mana = mini(MAX_MANA, player_max_mana + amount)
            player_mana = mini(player_max_mana, player_mana + amount)
        else:
            enemy_max_mana = mini(MAX_MANA, enemy_max_mana + amount)
            enemy_mana = mini(enemy_max_mana, enemy_mana + amount)
        await trigger_progress_growth(player_side)
        await show_vfx("+%d MAX PP" % amount, player_leader.global_position if player_side else enemy_leader.global_position, Color(0.55, 0.85, 1.0))
        if ability == "ramp_draw":
            draw_card(player_deck if player_side else enemy_deck, player_hand if player_side else enemy_hand)
            await show_vfx("DRAW", Vector2(550, 475 if player_side else 70), Color(0.55, 0.85, 1.0))
    elif ability in ["heal_draw", "guard_heal"]:
        if player_side: player_health = min(STARTING_HEALTH, player_health + amount)
        else: enemy_health = min(STARTING_HEALTH, enemy_health + amount)
        draw_card(player_deck if player_side else enemy_deck, player_hand if player_side else enemy_hand)
        await show_vfx("HEAL + DRAW", area_center(player_side), Color(0.4, 1.0, 0.65))
    elif ability == "heal_buff":
        if player_side: player_health = min(STARTING_HEALTH, player_health + amount)
        else: enemy_health = min(STARTING_HEALTH, enemy_health + amount)
        var allies: Array = player_board if player_side else enemy_board
        for ally in allies:
            if ally != unit:
                ally["health"] = int(ally["health"]) + amount; ally["max_health"] = int(ally["max_health"]) + amount; break
        await show_vfx("HELPING HAND", area_center(player_side), Color(0.55, 1.0, 0.75))
    elif ability == "heal_buff_comeback":
        if player_side: player_health = min(STARTING_HEALTH, player_health + amount)
        else: enemy_health = min(STARTING_HEALTH, enemy_health + amount)
        leader_feedback(player_leader if player_side else enemy_leader, amount, true)
        var hb_allies: Array = player_board if player_side else enemy_board
        var hb_foes: Array = enemy_board if player_side else player_board
        for ally in hb_allies:
            if ally != unit:
                ally["health"] = int(ally["health"]) + amount
                ally["max_health"] = int(ally["max_health"]) + amount
                break
        var foe_count: int = follower_count(hb_foes)
        var own_count: int = follower_count(hb_allies)
        if foe_count > own_count:
            draw_card(player_deck if player_side else enemy_deck, player_hand if player_side else enemy_hand)
            await show_vfx("HELPING HAND + DRAW", area_center(player_side), Color(0.55, 1.0, 0.75))
        else:
            await show_vfx("HELPING HAND", area_center(player_side), Color(0.55, 1.0, 0.75))
    elif ability == "renew_growth":
        # Arrival: Restore 1 defense (self-triggers the Renew passive this turn).
        if player_side: player_health = min(STARTING_HEALTH, player_health + 1)
        else: enemy_health = min(STARTING_HEALTH, enemy_health + 1)
        leader_feedback(player_leader if player_side else enemy_leader, 1, true)
        await show_vfx("+1 BEACON KEEPER", player_leader.global_position if player_side else enemy_leader.global_position, Color(0.4, 1.0, 0.55))
    elif ability == "morning_promise":
        var cur_hp: int = player_health if player_side else enemy_health
        if cur_hp >= 15:
            draw_card(player_deck if player_side else enemy_deck, player_hand if player_side else enemy_hand)
            var mp_board: Array = player_board if player_side else enemy_board
            var mp_idx: int = mp_board.find(unit)
            if mp_idx >= 0:
                mp_board[mp_idx]["attack"] = int(unit["attack"]) + 1
                mp_board[mp_idx]["health"] = int(unit["health"]) + 1
                mp_board[mp_idx]["max_health"] = int(unit.get("max_health", unit["health"])) + 1
            await show_vfx("MORNING PROMISE: DRAW + +1/+1", area_center(player_side), Color(1.0, 0.88, 0.45))
        else:
            await show_vfx("MORNING PROMISE: NEED 15+ DEF", area_center(player_side), Color(0.6, 0.6, 0.7))
    elif ability == "circle_support":
        var cs_allies: Array = player_board if player_side else enemy_board
        var cs_foes: Array = enemy_board if player_side else player_board
        if follower_count(cs_foes) > follower_count(cs_allies):
            for ally in cs_allies:
                if not bool(ally.get("is_amulet", false)):
                    ally["health"] = int(ally["health"]) + 1
                    ally["max_health"] = int(ally["max_health"]) + 1
            await show_vfx("CIRCLE OF SUPPORT: ALL ALLIES +0/+1", area_center(player_side), Color(0.45, 0.9, 0.65))
    elif ability in ["buff_all", "buff_all_attack"]:
        var allies: Array = player_board if player_side else enemy_board
        var area_ba: Control = player_board_area if player_side else enemy_board_area
        for i in range(allies.size()):
            var ally: Dictionary = allies[i]
            if ally == unit: continue
            ally["attack"] = int(ally["attack"]) + amount
            if ability == "buff_all":
                ally["health"] = int(ally["health"]) + amount; ally["max_health"] = int(ally["max_health"]) + amount
            var buff_str_ba := "+%d/+%d" % [amount, amount] if ability == "buff_all" else "+%d ATK" % amount
            show_buff_flash(find_card_view_for_board_index(area_ba, i), buff_str_ba, Color(1.0, 0.76, 0.25))
        await show_vfx("RALLY", area_center(player_side), Color(1.0, 0.76, 0.25))
    elif ability == "damage_unit":
        var foes: Array = enemy_board if player_side else player_board
        var target := strongest_index(foes)
        if target >= 0:
            foes[target]["health"] = int(foes[target]["health"]) - amount
            await show_vfx("-%d" % amount, area_center(not player_side), Color(1.0, 0.25, 0.18))
            if int(foes[target]["health"]) <= 0: await destroy_unit(foes, target, not player_side)
    elif ability == "damage_all":
        await damage_all_other_followers(unit, amount, player_side)
    elif ability in ["freeze", "bounce", "bounce_small"]:
        var foes: Array = enemy_board if player_side else player_board
        var target := strongest_index(foes)
        if ability == "bounce_small":
            target = first_cost_at_most(foes, amount)
        if target >= 0:
            if ability == "freeze":
                foes[target]["skip_next_attack"] = true; foes[target]["can_attack"] = false
                await show_vfx("CALM", area_center(not player_side), Color(0.5, 0.9, 1.0))
            else:
                return_unit_to_hand(foes, target, not player_side)
                await show_vfx("RETURNED", area_center(not player_side), Color(0.65, 0.8, 1.0))
    elif ability in ["cost_reduce", "draw_reduce", "cost_reduce_all"]:
        if ability == "draw_reduce":
            for i in range(maxi(1, amount)): draw_card(player_deck if player_side else enemy_deck, player_hand if player_side else enemy_hand)
        reduce_hand_cost(player_hand if player_side else enemy_hand, amount, ability == "cost_reduce_all")
        await show_vfx("PLAN AHEAD", area_center(player_side), Color(0.85, 0.72, 1.0))
    elif ability == "self_damage_draw":
        if player_side: player_health -= amount
        else: enemy_health -= amount
        draw_card(player_deck if player_side else enemy_deck, player_hand if player_side else enemy_hand)
        await show_vfx("PUSH FORWARD", area_center(player_side), Color(1.0, 0.35, 0.2))
    elif ability == "low_health_power":
        var hp := player_health if player_side else enemy_health
        if hp <= 10:
            unit["attack"] = int(unit["attack"]) + 3; unit["health"] = int(unit["health"]) + 3; unit["max_health"] = int(unit["max_health"]) + 3; unit["can_attack"] = true
            await show_vfx("LAST STAND +3/+3", area_center(player_side), Color(1.0, 0.25, 0.18))
    elif ability == "turning_point":
        var own_hp := player_health if player_side else enemy_health
        var foe_hp := enemy_health if player_side else player_health
        if own_hp < foe_hp:
            draw_card(player_deck if player_side else enemy_deck, player_hand if player_side else enemy_hand)
            draw_card(player_deck if player_side else enemy_deck, player_hand if player_side else enemy_hand)
            if player_side: player_max_mana = mini(MAX_MANA, player_max_mana + 1); player_mana = mini(player_max_mana, player_mana + 1)
            else: enemy_max_mana = mini(MAX_MANA, enemy_max_mana + 1); enemy_mana = mini(enemy_max_mana, enemy_mana + 1)
            await trigger_progress_growth(player_side)
            await show_vfx("TURNING POINT!", area_center(player_side), Color(0.60, 0.85, 1.0))
        else:
            draw_card(player_deck if player_side else enemy_deck, player_hand if player_side else enemy_hand)
            await show_vfx("TURNING POINT: DRAW", area_center(player_side), Color(0.60, 0.85, 1.0))
    elif ability == "draw_reduce_two":
        draw_card(player_deck if player_side else enemy_deck, player_hand if player_side else enemy_hand)
        draw_card(player_deck if player_side else enemy_deck, player_hand if player_side else enemy_hand)
        var hand_dr2 := player_hand if player_side else enemy_hand
        var sorted_idx: Array = range(hand_dr2.size())
        sorted_idx.sort_custom(func(a, b): return int(hand_dr2[a].get("cost", 0)) > int(hand_dr2[b].get("cost", 0)))
        var reduced := 0
        for idx in sorted_idx:
            if reduced >= 2: break
            if int(hand_dr2[idx].get("cost", 0)) > 0:
                hand_dr2[idx]["cost"] = int(hand_dr2[idx]["cost"]) - 1
                reduced += 1
        await show_vfx("REASSURANCE — PLAN AHEAD", area_center(player_side), Color(0.75, 0.92, 1.0))
    elif ability == "heal_draw_exhaust":
        if player_side: player_health = min(STARTING_HEALTH, player_health + amount)
        else: enemy_health = min(STARTING_HEALTH, enemy_health + amount)
        draw_card(player_deck if player_side else enemy_deck, player_hand if player_side else enemy_hand)
        var foes_exhaust: Array = enemy_board if player_side else player_board
        for foe in foes_exhaust:
            if not bool(foe.get("is_amulet", false)):
                foe["skip_next_attack"] = true
                foe["can_attack"] = false
        await show_vfx("PEACE BEYOND FEAR", area_center(player_side), Color(0.55, 0.85, 1.0))
    elif ability in ["revive", "revive_buff", "revive_charge", "revive_to_hand"]:
        await recover_from_relapse(player_side, ability, amount)
    elif ability == "revive_discount":
        var rd_relapse: Array = player_relapse if player_side else enemy_relapse
        if rd_relapse.is_empty():
            await show_vfx("RELAPSE ZONE EMPTY", area_center(player_side), Color(0.72, 0.72, 0.85))
        else:
            var rd_card: Dictionary = rd_relapse.pop_back()
            if bool(rd_card.get("evolved", false)) and not bool(rd_card.get("is_amulet", false)):
                rd_card = _strip_evolution_for_revival(rd_card)
            rd_card["health"] = int(rd_card.get("max_health", rd_card.get("health", 1)))
            rd_card["can_attack"] = false
            rd_card["cost"] = maxi(0, int(rd_card.get("cost", 0)) - 2)
            var rd_hand: Array = player_hand if player_side else enemy_hand
            var rd_deck: Array = player_deck if player_side else enemy_deck
            if rd_hand.size() < MAX_HAND: rd_hand.append(rd_card)
            else: rd_deck.push_front(rd_card)
            training_on_recovered(player_side)
            await trigger_leader_recovery_progress(player_side, "second_chances")
            await show_vfx("RECOVERY — -2 COST", area_center(player_side), Color(1.0, 0.78, 0.35))
    elif ability in ["board_clear", "board_clear_heal", "board_clear_draw"]:
        await clear_battlefield_except(unit, player_side)
        if ability == "board_clear_heal":
            if player_side: player_health = min(STARTING_HEALTH, player_health + amount)
            else: enemy_health = min(STARTING_HEALTH, enemy_health + amount)
        elif ability == "board_clear_draw":
            for i in range(2):
                draw_card(player_deck, player_hand); draw_card(enemy_deck, enemy_hand)
    elif ability == "board_clear_enemy_heal_draw":
        var bce_foes: Array = enemy_board if player_side else player_board
        for i in range(bce_foes.size() - 1, -1, -1):
            if not bool(bce_foes[i].get("is_amulet", false)):
                await destroy_unit(bce_foes, i, not player_side)
        if player_side: player_health = min(STARTING_HEALTH, player_health + amount)
        else: enemy_health = min(STARTING_HEALTH, enemy_health + amount)
        for _i in range(2):
            draw_card(player_deck if player_side else enemy_deck, player_hand if player_side else enemy_hand)
        await show_vfx("NEW BEGINNING", area_center(player_side), Color(1.0, 0.85, 0.62))
    elif ability == "heal_all":
        if player_side: player_health = min(STARTING_HEALTH, player_health + amount)
        else: enemy_health = min(STARTING_HEALTH, enemy_health + amount)
        for ally in (player_board if player_side else enemy_board): ally["health"] = mini(int(ally["max_health"]), int(ally["health"]) + amount)
        await show_vfx("RENEW", area_center(player_side), Color(0.45, 1.0, 0.6))
    elif ability == "progress_power":
        var bonus := maxi(0, (player_max_mana if player_side else enemy_max_mana) - turn_number)
        unit["attack"] = int(unit["attack"]) + bonus; unit["health"] = int(unit["health"]) + bonus; unit["max_health"] = int(unit["max_health"]) + bonus
    elif ability == "walking_free":
        buff_deck_followers(player_side, "Purpose", 1)
        if player_side:
            player_mana = mini(player_max_mana, player_mana + 2)
            player_walking_free_active = true
        else:
            enemy_mana = mini(enemy_max_mana, enemy_mana + 2)
            enemy_walking_free_active = true
        for _i in range(2):
            draw_card(player_deck if player_side else enemy_deck, player_hand if player_side else enemy_hand)
        await show_vfx("WALKING FREE — +1/+1 DECK • +2 PP • DRAW 2", area_center(player_side), Color(1.0, 0.9, 0.45))
    elif ability == "rally_the_free":
        buff_deck_followers(player_side, "Courage", 2)
        await show_vfx("RALLY THE FREE — COURAGE DECK +2/+2", area_center(player_side), Color(1.0, 0.34, 0.20))
    elif ability == "hope_platinum":
        await create_inspired_volunteer(player_side)
        await create_inspired_volunteer(player_side)
        await show_vfx("BEACON OF HOPE — INSPIRE THE ROOM", area_center(player_side), Color(1.0, 0.82, 0.35))
    elif ability == "serenity_platinum":
        if player_side:
            player_health = min(STARTING_HEALTH, player_health + 5)
        else:
            enemy_health = min(STARTING_HEALTH, enemy_health + 5)
        unit["serenity_save_active"] = true
        await show_vfx("INNER PEACE — RESTORE 5", area_center(player_side), Color(0.55, 0.9, 1.0))
    var _is_heal_ability := ability in ["heal_leader", "heal_leader_draw", "heal_draw", "guard_heal", "heal_buff", "heal_buff_comeback", "heal_all", "hope_platinum", "serenity_platinum", "board_clear_heal", "board_clear_enemy_heal_draw", "renew_growth", "morning_promise"]
    if _is_heal_ability:
        await apply_sanctuary_serenity_buff(player_side)
        _trigger_on_leader_healed(player_side)
    if player_side and _is_heal_ability:
        training_on_heal(maxi(1, amount))
    refresh_ui()


## Called after any heal event so passive "whenever leader healed" abilities fire.
## Abilities handled: renew_growth, guard_heal_buff (Dreamward Keeper), heal_grows (Inspired Volunteer).
func _trigger_on_leader_healed(player_side: bool) -> void:
    var board: Array = player_board if player_side else enemy_board
    for i in range(board.size()):
        var ab := str(board[i].get("ability", ""))
        if ab in ["renew_growth", "guard_heal_buff", "heal_grows"]:
            board[i]["attack"] = int(board[i].get("attack", 0)) + 1
            board[i]["health"] = int(board[i].get("health", 0)) + 1
            board[i]["max_health"] = int(board[i].get("max_health", board[i]["health"])) + 1
    refresh_ui()

func add_progress(player_side: bool, amount: int = 1) -> void:
    if player_side:
        player_progress_counters += amount
    else:
        enemy_progress_counters += amount

func trigger_progress_growth(player_side: bool) -> void:
    var board: Array = player_board if player_side else enemy_board
    for ally in board:
        if str(ally.get("ability", "")) == "progress_growth":
            ally["attack"] = int(ally.get("attack", 0)) + 1
            ally["health"] = int(ally.get("health", 0)) + 1
            ally["max_health"] = int(ally.get("max_health", ally.get("health", 0))) + 1
    add_progress(player_side, 1)

func trigger_finding_purpose_milestone(player_side: bool) -> void:
    var board: Array = player_board if player_side else enemy_board
    var active := false
    for ally in board:
        if str(ally.get("ability", "")) == "finding_purpose":
            active = true
            break
    if not active:
        return
    if player_side:
        player_max_mana = mini(MAX_MANA, player_max_mana + 1)
        player_mana = mini(player_max_mana, player_mana + 1)
        draw_card(player_deck, player_hand)
    else:
        enemy_max_mana = mini(MAX_MANA, enemy_max_mana + 1)
        enemy_mana = mini(enemy_max_mana, enemy_mana + 1)
        draw_card(enemy_deck, enemy_hand)
    await trigger_progress_growth(player_side)
    await show_vfx("PURPOSE DISCOVERED: +1 MAX PP + DRAW", area_center(player_side), Color(0.72, 0.82, 1.0))

func strongest_index(board: Array) -> int:
    var result := -1
    var score := -999
    for i in range(board.size()):
        if bool(board[i].get("is_amulet", false)):
            continue
        var current := int(board[i].get("attack", 0)) + int(board[i].get("health", 0))
        if current > score: score = current; result = i
    return result

func first_cost_at_most(board: Array, limit: int) -> int:
    for i in range(board.size()):
        if bool(board[i].get("is_amulet", false)):
            continue
        if int(board[i].get("cost", 0)) <= limit: return i
    return -1

func return_unit_to_hand(board: Array, index: int, owner_player_side: bool) -> void:
    if index < 0 or index >= board.size(): return
    var unit: Dictionary = board.pop_at(index)
    var hand: Array = player_hand if owner_player_side else enemy_hand
    var deck: Array = player_deck if owner_player_side else enemy_deck
    unit["health"] = int(unit.get("max_health", unit.get("health", 1)))
    unit["can_attack"] = false
    if hand.size() < MAX_HAND: hand.append(unit)
    else: deck.push_front(unit)

func reduce_hand_cost(hand: Array, amount: int, all_cards: bool) -> void:
    if hand.is_empty(): return
    if all_cards:
        for item in hand: item["cost"] = maxi(0, int(item.get("cost", 0)) - amount)
        return
    var idx := 0
    for i in range(1, hand.size()):
        if int(hand[i].get("cost", 0)) > int(hand[idx].get("cost", 0)): idx = i
    hand[idx]["cost"] = maxi(0, int(hand[idx].get("cost", 0)) - amount)

func _fresh_base_card(name: String, faction_hint: String) -> Dictionary:
    # Looks up a card's original, pre-evolution definition by name so a
    # revived follower can be reverted to its base stats instead of keeping
    # whatever evolution bonus it had when it died.
    if name == "":
        return {}
    var found := _find_card_by_name(build_universal_cards(), name)
    if not found.is_empty():
        return found
    var faction_classes := ["Hope", "Courage", "Serenity", "Purpose"]
    if faction_hint in faction_classes:
        found = _find_card_by_name(build_class_cards(faction_hint), name)
        if not found.is_empty():
            return found
    for faction_class in faction_classes:
        found = _find_card_by_name(build_class_cards(faction_class), name)
        if not found.is_empty():
            return found
    return {}

func _strip_evolution_for_revival(follower: Dictionary) -> Dictionary:
    # Evolution is a one-time battlefield power spike, not a permanent
    # upgrade to the card -- a follower coming back from the Relapse Zone
    # returns as its base, non-evolved self, the same as a fresh copy of
    # that card would be.
    var base := _fresh_base_card(str(follower.get("name", "")), str(follower.get("faction", "")))
    if base.is_empty():
        # No definition found (e.g. a one-off Training/story card) -- there's
        # nothing to revert numbers to, so just clear the evolved flag/badge
        # rather than losing the card or guessing at its base stats.
        follower["evolved"] = false
        follower["evolved_this_turn"] = false
        return follower
    follower["attack"] = int(base.get("attack", follower.get("attack", 0)))
    follower["health"] = int(base.get("health", follower.get("health", 0)))
    follower["max_health"] = int(base.get("health", follower.get("max_health", follower.get("health", 0))))
    follower["evolved"] = false
    follower["evolved_this_turn"] = false
    return follower

func recover_from_relapse(player_side: bool, mode: String, amount: int) -> void:
    var relapse: Array = player_relapse if player_side else enemy_relapse
    if relapse.is_empty():
        await show_vfx("RELAPSE ZONE EMPTY", area_center(player_side), Color(0.72, 0.72, 0.85)); return
    var recovered: Dictionary = relapse.pop_back()
    if bool(recovered.get("evolved", false)) and not bool(recovered.get("is_amulet", false)) and not bool(recovered.get("is_spell", false)):
        recovered = _strip_evolution_for_revival(recovered)
    recovered["health"] = int(recovered.get("max_health", recovered.get("health", 1)))
    recovered["can_attack"] = mode == "revive_charge"
    training_on_recovered(player_side)
    if mode == "revive_to_hand":
        var hand: Array = player_hand if player_side else enemy_hand
        var deck: Array = player_deck if player_side else enemy_deck
        if hand.size() < MAX_HAND: hand.append(recovered)
        else: deck.push_front(recovered)
    else:
        var board: Array = player_board if player_side else enemy_board
        if follower_count(board) >= MAX_BOARD:
            relapse.append(recovered); return
        if mode == "revive_buff":
            recovered["attack"] = int(recovered["attack"]) + amount; recovered["health"] = int(recovered["health"]) + amount; recovered["max_health"] = int(recovered["max_health"]) + amount
        board.append(recovered)
    await trigger_leader_recovery_progress(player_side, "second_chances")
    spawn_sparkle_burst(area_center(player_side),
        6 if CardView.graphics_quality >= 1 else 3,
        [Color(1.0, 0.82, 0.35), Color(0.55, 0.95, 1.0)], self, 55.0)
    await show_vfx("RECOVERY ✦", area_center(player_side), Color(1.0, 0.78, 0.35))

func clear_battlefield_except(source: Dictionary, source_player_side: bool) -> void:
    for i in range(enemy_board.size() - 1, -1, -1):
        if (source_player_side or enemy_board[i] != source) and not bool(enemy_board[i].get("is_amulet", false)):
            await destroy_unit(enemy_board, i, false)
    for i in range(player_board.size() - 1, -1, -1):
        if (not source_player_side or player_board[i] != source) and not bool(player_board[i].get("is_amulet", false)): await destroy_unit(player_board, i, true)
    await show_vfx("ROCK BOTTOM", Vector2(520, 260), Color(1.0, 0.45, 0.18))

func damage_all_other_followers(source: Dictionary, amount: int, source_player_side: bool) -> void:
    for i in range(enemy_board.size() - 1, -1, -1):
        if bool(enemy_board[i].get("is_amulet", false)):
            continue
        enemy_board[i]["health"] = int(enemy_board[i]["health"]) - amount
        if int(enemy_board[i]["health"]) <= 0: await destroy_unit(enemy_board, i, false)
    for i in range(player_board.size() - 1, -1, -1):
        if player_board[i] == source or bool(player_board[i].get("is_amulet", false)): continue
        player_board[i]["health"] = int(player_board[i]["health"]) - amount
        if int(player_board[i]["health"]) <= 0: await destroy_unit(player_board, i, true)
    await show_vfx("BOARD IMPACT", Vector2(520, 260), Color(1.0, 0.35, 0.2))

func card_clicked(index: int, player_side: bool) -> void:
    if game_over or busy or not player_turn_active: return
    if player_side:
        if index < 0 or index >= player_board.size(): return
        if selected_evolution_cost > 0:
            busy = true
            await evolve_follower(index, selected_evolution_cost, true)
            busy = false
            return
        if bool(player_board[index].get("is_amulet", false)):
            status_label.text = "Amulets cannot attack."
            return
        if not bool(player_board[index].get("can_attack", false)):
            safe_set_text(status_label, "%s is resting." % str(player_board[index].get("name", "That follower")))
            return
        safe_set_text(status_label, "Drag %s to attack." % str(player_board[index].get("name", "follower")))
    else:
        if selected_attacker < 0: return
        if not _drag_attack_pending: return  # attacks must originate from a drag, never from a tap
        if index >= 0 and index < enemy_board.size() and bool(enemy_board[index].get("is_amulet", false)):
            status_label.text = "That Recovery Skill cannot be attacked. Use an effect that targets Recovery Skills."
            return
        if index >= 0 and index < enemy_board.size():
            var target_text := (str(enemy_board[index].get("text", "")) + " " + str(enemy_board[index].get("display_text", ""))).to_lower()
            if "cannot be attacked" in target_text:
                status_label.text = "%s cannot be attacked." % str(enemy_board[index].get("name", "That follower"))
                return
        var guard := first_guard_index(enemy_board)
        if guard >= 0 and index != guard: status_label.text = "A Protector must be attacked first."; return
        await perform_player_attack(index)

func leader_clicked(player_side: bool) -> void:
    if player_side or selected_attacker < 0 or busy or not player_turn_active: return
    if not _drag_attack_pending: return  # leader attacks must originate from a drag, never from a tap
    if first_guard_index(enemy_board) >= 0: status_label.text = "A Protector must be attacked first."; return
    if selected_attacker >= player_board.size(): return
    var attacker: Dictionary = player_board[selected_attacker]
    var effect_text := (str(attacker.get("text", "")) + " " + str(attacker.get("display_text", "")) + " " + str(attacker.get("ability", ""))).to_lower()
    # Evolving only blocks a leader attack when the follower ALSO has summoning
    # sickness (i.e. it was played this same turn) and lacks Storm/Breakthrough.
    # A follower that has been on the field since an earlier turn keeps its
    # right to attack the leader when it evolves, storm or not.
    var summoned_this_turn := int(attacker.get("summoned_turn", -1)) == turn_number
    if bool(attacker.get("evolved_this_turn", false)) and summoned_this_turn and not ("breakthrough" in effect_text or "storm" in effect_text):
        status_label.text = "A follower that evolved this turn can attack followers, not the enemy leader."
        return
    await perform_player_attack(-1)

func perform_player_attack(target_index: int) -> void:
    if selected_attacker < 0 or selected_attacker >= player_board.size(): return
    busy = true
    var attacker_index := selected_attacker; selected_attacker = -1
    var attacker_data: Dictionary = player_board[attacker_index]
    var ability := str(attacker_data.get("ability", ""))
    # Rush only restricts attacking the leader on the turn the follower was
    # summoned (it trades summoning sickness for "can attack followers right
    # away"). "ability" is a permanent tag on the card, so without checking
    # summoned_turn this blocked Rush followers from ever attacking the
    # leader again, on every later turn as well.
    var summoned_this_turn := int(attacker_data.get("summoned_turn", -1)) == turn_number
    if ability == "rush" and target_index < 0 and summoned_this_turn: status_label.text = "Rush can only attack enemy allies this turn."; busy = false; refresh_ui(); return
    await animate_attack(attacker_index, target_index, true)
    busy = false; refresh_ui()

func animate_attack(attacker_index: int, target_index: int, player_side: bool) -> void:
    if attacker_index < 0: return
    var area: Control = player_board_area if player_side else enemy_board_area
    var view: CardView = find_card_view_for_board_index(area, attacker_index)
    if view == null: return

    var attacker_card: Dictionary = (player_board if player_side else enemy_board)[attacker_index]

    # Global center of the attacker.
    var from_center: Vector2 = view.global_position + view.size * 0.5

    # Global center of the target (leader or follower).
    var to_center: Vector2
    if target_index < 0:
        var tl: Control = enemy_leader if player_side else player_leader
        to_center = tl.global_position + tl.size * 0.5
    else:
        var t_area: Control = enemy_board_area if player_side else player_board_area
        var tv: CardView = find_card_view_for_board_index(t_area, target_index)
        if tv == null: return
        to_center = tv.global_position + tv.size * 0.5

    var attack_dir: Vector2 = (to_center - from_center).normalized()

    # Signature voice for platinum / flagship abilities.
    if str(attacker_card.get("ability", "")) in ["walking_free", "rally_the_free", "hope_platinum", "serenity_platinum"]:
        await play_signature_voice(str(attacker_card.get("name", "")), player_side, true)

    play_sfx("attack_swing_clean")
    view.z_index = 300

    # 1. Wind-up: card squashes and leans away from target.
    view.play_attack_wind_up(-attack_dir)
    await get_tree().create_timer(0.13, true, false, true).timeout

    # 2. Lunge: card stretches toward target at the moment of release.
    view.play_attack_lunge(attack_dir)
    await get_tree().create_timer(0.09, true, false, true).timeout

    # 3. Projectile launches from the card toward the target.
    var proj_type: String  = _projectile_type_for_card(attacker_card)
    var rarity: String     = str(attacker_card.get("rarity", "Bronze"))
    var travel_time: float = _launch_projectile(from_center, to_center, proj_type, rarity)

    # 4. Await projectile arrival, then apply impact.
    await get_tree().create_timer(travel_time, true, false, true).timeout
    play_sfx(attack_impact_sound(attacker_index, target_index, player_side))

    var rtier: int        = _rarity_tier_int(rarity)
    var impact_col: Color = _projectile_impact_color(proj_type, rarity)
    var impact_dir: Vector2 = (to_center - from_center).normalized()

    # Rarity-calibrated directional shake: Bronze = barely perceptible, Platinum = satisfying
    const SHAKE_INTENSITY := [0.8, 1.8, 3.5, 5.5, 8.0, 11.0]
    const SHAKE_DURATION  := [0.15, 0.19, 0.22, 0.25, 0.27, 0.30]
    _screen_shake(SHAKE_INTENSITY[rtier], SHAKE_DURATION[rtier], impact_dir)
    _spawn_impact_flash(to_center, impact_col, rtier)
    _spawn_impact_sparks(to_center, impact_col, 7 + rtier * 3)
    _spawn_impact_ring(to_center, impact_col, rtier)

    # Hit stop — tiny freeze before damage resolves makes the hit feel heavier.
    await get_tree().create_timer(0.04 + rtier * 0.005, true, false, true).timeout

    # 5. Combat resolves on impact.
    await resolve_combat(attacker_index, target_index, player_side)

    # 6. Card settles back to idle pose.
    if is_instance_valid(view):
        view.play_attack_settle()
        view.z_index = 0

func animate_enemy_attack(attacker_index: int, target_index: int) -> void:
    if attacker_index < 0 or attacker_index >= enemy_board.size(): return
    await animate_attack(attacker_index, target_index, false)

func resolve_combat(attacker_index: int, target_index: int, player_side: bool) -> void:
    var attack_board := player_board if player_side else enemy_board
    var defend_board := enemy_board if player_side else player_board
    if attacker_index < 0 or attacker_index >= attack_board.size(): return
    var attacker: Dictionary = attack_board[attacker_index]; attacker["can_attack"] = false
    if player_side: player_attacked_this_turn = true
    else: enemy_attacked_this_turn = true
    if target_index < 0:
        if player_side: enemy_health -= int(attacker["attack"])
        else: player_health -= int(attacker["attack"])
        leader_feedback(enemy_leader if player_side else player_leader, int(attacker["attack"]), false)
        play_battle_bark(player_leader if player_side else enemy_leader, selected_class if player_side else enemy_class, "attack", player_side)
        await trigger_leader_recovery_progress(player_side, "standing_ground")
        show_damage_number(int(attacker["attack"]), (enemy_leader if player_side else player_leader).global_position + Vector2(45, 18), str(attacker.get("rarity", "Bronze")))
        if player_side and training_mode:
            training_attacked_this_turn = true
    else:
        if target_index >= defend_board.size(): return
        if bool(defend_board[target_index].get("is_amulet", false)):
            return
        var defender: Dictionary = defend_board[target_index]
        # Combat damage is simultaneous. Snapshot both attack values first,
        # then calculate and store each unit's remaining defense explicitly.
        var attacker_damage: int = int(attacker.get("attack", 0))
        var defender_damage: int = int(defender.get("attack", 0))
        var defender_remaining: int = int(defender.get("health", 0)) - attacker_damage
        var attacker_remaining: int = int(attacker.get("health", 0)) - defender_damage

        defender["health"] = defender_remaining
        attacker["health"] = attacker_remaining
        defend_board[target_index] = defender
        attack_board[attacker_index] = attacker

        show_damage_number(attacker_damage, (enemy_board_area if player_side else player_board_area).global_position + Vector2(80 + target_index * 145, 28), str(attacker.get("rarity", "Bronze")))

        # Flash the defender card on impact.
        var def_area: Control = enemy_board_area if player_side else player_board_area
        var def_view: CardView = find_card_view_for_board_index(def_area, target_index)
        if is_instance_valid(def_view):
            def_view.damage_flash()
        # Flash the attacker card if it took counter-damage.
        var atk_area: Control = player_board_area if player_side else enemy_board_area
        var view: CardView = find_card_view_for_board_index(atk_area, attacker_index)
        if defender_damage > 0 and is_instance_valid(view):
            view.damage_flash()
            show_damage_number(defender_damage, atk_area.global_position + Vector2(80 + attacker_index * 145, 28), str(defender.get("rarity", "Bronze")))

        # A unit survives whenever it has at least 1 defense remaining.
        var defender_died: bool = defender_remaining <= 0
        var attacker_died: bool = attacker_remaining <= 0
        if player_side:
            training_on_attack(target_index, not attacker_died, defender_died)
        if defender_died:
            await destroy_unit(defend_board, target_index, not player_side)
        if attacker_died and attacker_index < attack_board.size():
            await destroy_unit(attack_board, attacker_index, player_side)
        # Survive-buff abilities fire after both destroy_unit calls so a unit
        # that died does not erroneously receive its own buff.
        if not attacker_died and attacker_index < attack_board.size():
            await _check_survive_buff(attack_board, attacker_index, player_side, defender_damage, true)
        if not defender_died and target_index < defend_board.size():
            await _check_survive_buff(defend_board, target_index, not player_side, attacker_damage, false)
    check_winner(); refresh_ui()

func destroy_unit(board: Array, index: int, player_side: bool, specifically_targets_amulet: bool = false) -> void:
    if index < 0 or index >= board.size(): return
    var dead: Dictionary = board[index]
    if bool(dead.get("is_amulet", false)) and not specifically_targets_amulet:
        return
    # Ward-break VFX — show before the follower is removed.
    if str(dead.get("ability", "")) in ["guard", "guard_heal", "guard_heal_buff", "guard_protect", "rise_together"]:
        var ward_area: Control = player_board_area if player_side else enemy_board_area
        show_vfx("WARD BROKEN", ward_area.global_position + Vector2(90 + index * 145, 20), Color(0.45, 0.75, 1.0))
    if bool(dead.get("sponsor_protection", false)):
        dead["sponsor_protection"] = false
        dead["health"] = 1
        board[index] = dead
        var protected_area: Control = player_board_area if player_side else enemy_board_area
        await show_vfx("SPONSOR SAVES SPONSEE", protected_area.global_position + Vector2(210 + index * 85, 45), Color(1.0, 0.86, 0.38))
        return
    # Guardian Angel (guard_protect) — the first OTHER allied follower destroyed
    # each game is saved at 1 defense. The Guardian cannot save itself.
    if not bool(dead.get("is_amulet", false)):
        for gi in range(board.size()):
            if gi == index:
                continue  # Guardian Angel cannot save itself
            var guardian: Dictionary = board[gi]
            if str(guardian.get("ability", "")) == "guard_protect" and not bool(guardian.get("guardian_used", false)):
                board[gi]["guardian_used"] = true
                dead["health"] = 1
                dead["max_health"] = maxi(int(dead.get("max_health", 1)), 1)
                board[index] = dead
                var ga_area: Control = player_board_area if player_side else enemy_board_area
                show_vfx("GUARDIAN ANGEL SAVES ALLY!", ga_area.global_position + Vector2(90 + index * 145, 20), Color(0.55, 0.90, 1.0))
                await get_tree().create_timer(0.45).timeout
                refresh_ui()
                return
    if bool(dead.get("is_sponsee", false)):
        var path := selected_class if player_side else enemy_class
        var heal_amount := 5 if path == "Hope" else (3 if path == "Serenity" else (2 if path == "Courage" else 1))
        if player_side:
            player_health = min(STARTING_HEALTH, player_health + heal_amount)
        else:
            enemy_health = min(STARTING_HEALTH, enemy_health + heal_amount)
        await show_vfx("SPONSEE LEGACY +%d" % heal_amount, area_center(player_side), Color(0.45,1.0,0.62))
    if str(dead.get("ability", "")) == "phoenix_rising" and not bool(dead.get("was_banished", false)) and not bool(dead.get("was_transformed", false)):
        var tier := int(dead.get("phoenix_tier", 1))
        var area_ph: Control = player_board_area if player_side else enemy_board_area
        var dead_view_ph: CardView = find_card_view_for_board_index(area_ph, index)
        if dead_view_ph != null:
            dead_view_ph.phoenix_death_animation()
            await get_tree().create_timer(0.45).timeout
        training_on_follower_lost(player_side)
        board.remove_at(index)
        if tier >= 10:
            var rz: Array = player_relapse if player_side else enemy_relapse
            rz.append(dead.duplicate(true))
            await show_vfx("NOTHING CAN BREAK MY RESOLVE!", area_center(player_side), Color(1.0, 0.82, 0.34))
        else:
            if player_side: phoenix_pending_player = true; phoenix_tier_player = tier + 1
            else: phoenix_pending_enemy = true; phoenix_tier_enemy = tier + 1
            await show_vfx("GETS BACK UP!", area_center(player_side), Color(1.0, 0.65, 0.25))
        refresh_ui()
        return
    var area := player_board_area if player_side else enemy_board_area
    var dead_view: CardView = find_card_view_for_board_index(area, index)
    if dead_view != null:
        # Death impact burst — rarity-scaled spark shower before the card collapses.
        var death_center := dead_view.global_position + dead_view.size * 0.5
        var dead_rarity  := str(dead.get("rarity", "Bronze"))
        _spawn_impact_sparks(death_center, _projectile_impact_color("punch", dead_rarity),
            8 + _rarity_tier_int(dead_rarity) * 3)
        dead_view.death_animation()
        await get_tree().create_timer(0.30, true, false, true).timeout
        _spawn_relapse_entry_vfx(death_center, player_side)
    training_on_follower_lost(player_side)
    board.remove_at(index)
    var relapse_zone: Array = player_relapse if player_side else enemy_relapse
    relapse_zone.append(dead.duplicate(true))
    if dead.get("ability", "") == "final_draw":
        for i in range(int(dead.get("amount", 1))): draw_card(player_deck if player_side else enemy_deck, player_hand if player_side else enemy_hand)
        await show_vfx("FINAL BREATH", area.global_position + Vector2(275, 45), Color(0.78, 0.55, 1.0))

func first_guard_index(board: Array) -> int:
    for i in range(board.size()):
        if bool(board[i].get("is_amulet", false)):
            continue
        if str(board[i].get("ability", "")) in ["guard", "guard_heal", "guard_heal_buff", "guard_protect", "rise_together"]: return i
    return -1

func check_winner() -> void:
    if game_over:
        return
    if enemy_health <= 0:
        enemy_health = 0
        game_over = true
        player_turn_active = false
        busy = true
        pending_match_rewards = []
        if not practice_mode:
            var challenge_reward := award_pending_challenge()
            var recovery_reward := record_recovery_challenge_win(selected_class)
            var trial_reward := award_pending_trial()
            pending_match_rewards = _combine_reward_lines([challenge_reward, recovery_reward, trial_reward])
        play_battle_bark(player_leader, selected_class, "victory", true, true)
        play_battle_bark(enemy_leader, enemy_class, "defeat", false, true)
        call_deferred("_finish_match", true)
    elif player_health <= 0:
        player_health = 0
        game_over = true
        player_turn_active = false
        busy = true
        play_battle_bark(enemy_leader, enemy_class, "victory", false, true)
        play_battle_bark(player_leader, selected_class, "defeat", true, true)
        call_deferred("_finish_match", false)

func _finish_match(player_won: bool) -> void:
    # End the match immediately and clear every interaction state before any
    # result animation begins. This prevents targeting prompts, dragging, turn
    # timers, and AI actions from remaining active behind the results screen.
    game_over = true
    player_turn_active = false
    busy = true
    selected_attacker = -1
    selected_evolution_cost = 0
    turn_time_left = 0.0
    slacking_warning_shown = true
    urgent_warning_shown = true
    if is_instance_valid(slacking_popup):
        slacking_popup.queue_free()
    safe_set_text(status_label, "Match complete.")
    refresh_ui()
    # A card-inspect panel left open (long-press on a card or leader) sits at
    # z_index 5000 and blocks END TURN/the timer underneath it. If it's still
    # open when the match ends it can make the result screen look broken or
    # unreachable, so always clear it before the result sequence starts.
    close_card_details()
    # class_overlay (z 2000) and second_chance_overlay (z 4000) both capture
    # every click while visible. Either one left alive across a match end sits
    # above the victory/defeat screen and silently eats input on PLAY AGAIN /
    # RETURN TO MAIN MENU, which is exactly what "stuck on the result screen"
    # looks like from the player's side. Force them closed unconditionally.
    if is_instance_valid(class_overlay):
        class_overlay.queue_free()
    if is_instance_valid(second_chance_overlay):
        second_chance_overlay.queue_free()

    if player_won and training_mode:
        var objectives := training_objectives(training_class)
        if training_objective_index >= objectives.size() - 1:
            training_objective_index = objectives.size()
            update_training_panel()
            complete_class_training()
        else:
            safe_set_text(status_label, "Battle won, but complete every class objective to graduate.")

    # This used to fire the cinematic without awaiting it, then cut it off
    # after a guessed 1.55s delay -- but the cinematic's own steps (loser
    # vfx, winner bounce, sparkles, banner in/hold/out) add up to roughly
    # 2.2s+ on their own, so that guess was *always* shorter than the real
    # sequence and would tear finish_layer down mid-banner every single time,
    # which is exactly the "victory screen overlapping/undimmed" bug reported
    # repeatedly. Every step inside _play_victory_sequence now awaits a fixed
    # timer (not an open-ended tween.finished), so it always completes in
    # bounded time -- await it directly instead of racing it with a guess.
    if player_won:
        play_sfx("victory")
        await _play_victory_sequence(player_leader, enemy_leader)
    else:
        play_sfx("defeat")
        await _play_victory_sequence(enemy_leader, player_leader)

    if is_instance_valid(training_panel):
        training_panel.queue_free()
    if player_won:
        show_game_over("VICTORY", "You are Walking Free!", true, pending_match_rewards)
    else:
        show_game_over("YOU LOSE", "Every setback is a chance to begin again.", false, [])
    pending_match_rewards = []
    busy = false

func _play_victory_sequence(winner: Control, loser: Control) -> void:
    # See the victory_sequence_token comment at its declaration: this token is
    # the real cutoff, not is_instance_valid(finish_layer) alone. Every await
    # checkpoint below re-checks it so a show_game_over that fires mid-cinematic
    # can never let this coroutine add one more node.
    victory_sequence_token += 1
    var my_token := victory_sequence_token
    # Freeze the board for a clear finish and lower the meditation track so the
    # result sound and animation have room.
    if is_instance_valid(music_player):
        var music_fade := create_tween()
        music_fade.tween_property(music_player, "volume_db", -16.0, 0.45)

    finish_layer = Control.new()
    finish_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    finish_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    finish_layer.z_index = 500
    if not safe_add_child(self, finish_layer):
        return

    var flash := ColorRect.new()
    flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    flash.color = Color(1.0, 0.86, 0.32, 0.0)
    flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
    finish_layer.add_child(flash)
    var flash_tween := create_tween()
    flash_tween.tween_property(flash, "color:a", 0.30, 0.15)
    flash_tween.tween_property(flash, "color:a", 0.0, 0.45)

    # Leaders keep their own infinite idle-bob tween running on this same
    # "scale" property (see start_leader_idle) for as long as they're on
    # screen, including through the end of the match. That tween is never
    # stopped, so it keeps fighting this sequence's tweens for the same
    # property indefinitely. `await <tween>.finished` only fires on a clean
    # natural finish -- if this tween is ever interrupted (freed target,
    # killed by an unrelated system, etc.) that signal never arrives and the
    # whole coroutine hangs forever on the VICTORY banner. Awaiting a fixed
    # timer matching each tween's own duration instead (the same fix already
    # applied one level up in _finish_match) makes every step here
    # unconditionally advance no matter what happens to the tween itself.
    if is_instance_valid(loser):
        var loser_start_rotation := loser.rotation
        var loser_start_scale := loser.scale
        var loser_tween := create_tween().set_parallel(true)
        loser_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
        loser_tween.tween_property(loser, "rotation", loser_start_rotation + deg_to_rad(-10.0), 0.42)
        loser_tween.tween_property(loser, "modulate", Color(0.25, 0.28, 0.36, 0.45), 0.42)
        loser_tween.tween_property(loser, "scale", loser_start_scale * 0.78, 0.42)
        await get_tree().create_timer(0.42, true, false, true).timeout
        # show_game_over runs on its own fixed timer in _finish_match and can
        # cut this sequence off out from under it (it's deliberately
        # fire-and-forget, see the comment there). Every await below is a
        # point where that can happen, so re-check the token before touching
        # finish_layer again -- otherwise the next finish_layer.add_child call
        # either crashes on a freed instance, or -- worse -- silently
        # succeeds for one more frame against a layer that's about to be
        # torn down, which is what let the cinematic's own banner bleed into
        # the result screen underneath.
        if my_token != victory_sequence_token or not is_instance_valid(finish_layer):
            return
        await show_vfx("DEFEATED", loser.global_position + Vector2(28, 35), Color(1.0, 0.34, 0.28))
        if my_token != victory_sequence_token or not is_instance_valid(finish_layer):
            return

    if is_instance_valid(winner):
        var original_scale := winner.scale
        var original_rotation := winner.rotation
        var winner_tween := create_tween()
        winner_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        winner_tween.tween_property(winner, "scale", original_scale * 1.28, 0.28)
        winner_tween.parallel().tween_property(winner, "rotation", original_rotation + deg_to_rad(2.5), 0.28)
        winner_tween.tween_property(winner, "scale", original_scale * 1.12, 0.22)
        winner_tween.parallel().tween_property(winner, "rotation", original_rotation, 0.22)
        await get_tree().create_timer(0.5, true, false, true).timeout
        if my_token != victory_sequence_token or not is_instance_valid(finish_layer):
            return

        for i in range(18):
            var sparkle := Label.new()
            sparkle.text = ["✦", "★", "•"][i % 3]
            sparkle.add_theme_font_size_override("font_size", ui_font(18 + (i % 3) * 4))
            sparkle.add_theme_color_override("font_color", Color(1.0, 0.74 + float(i % 3) * 0.08, 0.24))
            sparkle.position = winner.global_position + Vector2(70, 55)
            sparkle.mouse_filter = Control.MOUSE_FILTER_IGNORE
            finish_layer.add_child(sparkle)
            var angle := TAU * float(i) / 18.0
            var distance := 105.0 + float((i % 4) * 18)
            var destination := sparkle.position + Vector2(cos(angle), sin(angle)) * distance
            var sparkle_tween := create_tween().set_parallel(true)
            sparkle_tween.tween_property(sparkle, "position", destination, 0.72)
            sparkle_tween.tween_property(sparkle, "modulate:a", 0.0, 0.72)
            sparkle_tween.tween_property(sparkle, "rotation", angle + 1.5, 0.72)
            sparkle_tween.finished.connect(sparkle.queue_free)

        # Dim the busy board behind the banner so the announcement reads
        # cleanly instead of colliding visually with the board underneath.
        var scrim := ColorRect.new()
        scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        scrim.color = Color(0.01, 0.015, 0.03, 0.0)
        scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
        finish_layer.add_child(scrim)
        var scrim_tween := create_tween()
        scrim_tween.tween_property(scrim, "color:a", 0.58, 0.24)

        var banner_backdrop := Panel.new()
        banner_backdrop.position = Vector2(360, 220)
        banner_backdrop.size = Vector2(560, 140)
        banner_backdrop.pivot_offset = banner_backdrop.size * 0.5
        banner_backdrop.scale = Vector2(0.25, 0.25)
        banner_backdrop.modulate = Color(1, 1, 1, 0)
        var backdrop_style := StyleBoxFlat.new()
        backdrop_style.bg_color = Color(0.03, 0.05, 0.08, 0.88)
        backdrop_style.border_color = Color(1.0, 0.86, 0.30, 0.8)
        backdrop_style.set_border_width_all(2)
        backdrop_style.set_corner_radius_all(20)
        backdrop_style.shadow_color = Color(0, 0, 0, 0.6)
        backdrop_style.shadow_size = 16
        banner_backdrop.add_theme_stylebox_override("panel", backdrop_style)
        finish_layer.add_child(banner_backdrop)

        var banner := Label.new()
        banner.text = "VICTORY"
        banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        banner.position = Vector2(390, 238)
        banner.size = Vector2(500, 110)
        banner.pivot_offset = banner.size * 0.5
        banner.scale = Vector2(0.25, 0.25)
        banner.modulate = Color(1, 1, 1, 0)
        banner.add_theme_font_size_override("font_size", ui_font(70))
        banner.add_theme_color_override("font_color", Color(1.0, 0.86, 0.30))
        banner.add_theme_color_override("font_shadow_color", Color(0.08, 0.05, 0.12, 0.95))
        banner.add_theme_constant_override("shadow_offset_x", 5)
        banner.add_theme_constant_override("shadow_offset_y", 5)
        finish_layer.add_child(banner)
        var banner_tween := create_tween().set_parallel(true)
        banner_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        banner_tween.tween_property(banner, "scale", Vector2.ONE, 0.42)
        banner_tween.tween_property(banner, "modulate:a", 1.0, 0.24)
        banner_tween.tween_property(banner_backdrop, "scale", Vector2.ONE, 0.42)
        banner_tween.tween_property(banner_backdrop, "modulate:a", 1.0, 0.24)
        await get_tree().create_timer(0.42, true, false, true).timeout
        if my_token != victory_sequence_token or not is_instance_valid(finish_layer):
            return
        await get_tree().create_timer(0.65, true, false, true).timeout
        if my_token != victory_sequence_token or not is_instance_valid(finish_layer):
            return
        var banner_out := create_tween()
        banner_out.tween_property(banner, "modulate:a", 0.0, 0.22)
        banner_out.parallel().tween_property(banner_backdrop, "modulate:a", 0.0, 0.22)
        banner_out.parallel().tween_property(scrim, "color:a", 0.0, 0.22)
        await get_tree().create_timer(0.22, true, false, true).timeout

    if is_instance_valid(finish_layer):
        finish_layer.queue_free()
    await get_tree().create_timer(0.18).timeout

func record_recovery_challenge_win(winning_class: String) -> Dictionary:
    # Tracks the home screen's "Win 3 matches with <class>" Recovery
    # Challenge. Progress is stored directly in the shared profile file
    # (main.gd and menu.gd are separate scenes) and read back by the menu
    # the next time it loads or rebuilds the home screen.
    if winning_class == "":
        return {}
    var cfg := _load_shared_profile_cfg_for_partial_write()
    if cfg == null:
        return {}

    # Reset progress if we've rolled into a new week.
    var current_week := str(int(Time.get_unix_time_from_system() / 604800.0))
    var saved_week := str(cfg.get_value("challenge", "week_key", ""))
    var progress: Dictionary = cfg.get_value("challenge", "recovery_progress", {})
    if saved_week != current_week:
        progress = {}
        cfg.set_value("challenge", "week_key", current_week)

    var count := int(progress.get(winning_class, 0)) + 1
    var result := {}
    if count >= 3:
        var gold := int(cfg.get_value("economy", "gold", 0))
        var packs := int(cfg.get_value("economy", "packs", 0))
        cfg.set_value("economy", "gold", gold + 75)
        cfg.set_value("economy", "packs", packs + 1)
        progress[winning_class] = 0
        result = {"gold": 75, "packs": 1}
    else:
        progress[winning_class] = count
    cfg.set_value("challenge", "recovery_progress", progress)
    cfg.save("user://journeys_dawn_profile.cfg")
    return result

func award_pending_challenge() -> Dictionary:
    var cfg := ConfigFile.new()
    if cfg.load("user://journeys_dawn_profile.cfg") != OK:
        return {}
    var reward := int(cfg.get_value("challenge", "pending_reward", 0))
    var pack_reward := int(cfg.get_value("challenge", "pending_packs", 0))
    if reward <= 0 and pack_reward <= 0:
        return {}
    var challenge_name := str(cfg.get_value("challenge", "name", "Recovery Road"))
    var gold := int(cfg.get_value("economy", "gold", 600))
    var packs := int(cfg.get_value("economy", "packs", 0))
    var first_key := "cleared_" + challenge_name.to_lower().replace(" ", "_")
    var first_clear := not bool(cfg.get_value("road", first_key, false))
    var bonus_special := ""
    if challenge_name == "Recovery Master" and first_clear:
        reward += 500
        bonus_special = "Recovery Master Cleared: +500 Bonus Gold"
    cfg.set_value("economy", "gold", gold + reward)
    cfg.set_value("economy", "packs", packs + pack_reward)
    cfg.set_value("road", first_key, true)
    var story_stage := int(cfg.get_value("challenge", "story_stage", 0))
    if story_stage > 0:
        # Each leader (Hope/Courage/Serenity/Purpose) now has its own 24-stage
        # story arc with its own cast, so progress must be keyed per leader --
        # otherwise clearing stage 3 as one leader would also mark stage 3
        # cleared for every other leader's unrelated story. story_stage_leader
        # is stamped by begin_story_stage in menu.gd right before battle.
        var story_leader := str(cfg.get_value("challenge", "story_stage_leader", selected_class))
        cfg.set_value("story", "cleared_%d" % story_stage, true)
        cfg.set_value("story", "cleared_%s_%d" % [story_leader, story_stage], true)
        # 24 total story stages across 4 chapters (6 stages each) per leader —
        # keep in sync with STORY_STAGES_BY_LEADER in menu.gd. Capped so
        # unlocked_stage never points past the final stage once the whole arc
        # is cleared.
        cfg.set_value("story", "unlocked_stage", min(24, story_stage + 1))
        cfg.set_value("story", "unlocked_stage_%s" % story_leader, min(24, story_stage + 1))
    cfg.set_value("challenge", "pending_reward", 0)
    cfg.set_value("challenge", "pending_packs", 0)
    cfg.set_value("challenge", "story_stage", 0)
    cfg.save("user://journeys_dawn_profile.cfg")
    var out := {"gold": reward, "packs": pack_reward}
    if bonus_special != "":
        out["special"] = bonus_special
    return out

const TRIAL_GOLD_REWARDS := {1: 50, 2: 90, 3: 150, 4: 400}

func award_pending_trial() -> Dictionary:
    # Mirrors award_pending_challenge's pattern: menu.gd stamps a pending
    # trial into the shared profile cfg before launching the battle scene,
    # and this reads/clears it on victory. Trials are repeatable -- gold is
    # paid out on every win -- but The Sponsor's cosmetic + collection
    # reward only unlocks the first time he's beaten.
    var cfg := ConfigFile.new()
    if cfg.load("user://journeys_dawn_profile.cfg") != OK:
        return {}
    var opponent := str(cfg.get_value("trials", "pending_opponent", ""))
    var tier := int(cfg.get_value("trials", "pending_tier", 0))
    if opponent.is_empty() or tier <= 0:
        return {}
    var gold := int(cfg.get_value("economy", "gold", 0))
    var gold_awarded := int(TRIAL_GOLD_REWARDS.get(tier, 0))
    gold += gold_awarded
    cfg.set_value("economy", "gold", gold)
    var cleared = cfg.get_value("trials", "cleared", {})
    var clear_key := "%s_%d" % [opponent, tier]
    var first_clear := not bool(cleared.get(clear_key, false))
    cleared[clear_key] = true
    cfg.set_value("trials", "cleared", cleared)
    var special := ""
    if tier >= 4:
        if first_clear:
            var shiny_owned = cfg.get_value("collection", "shiny_owned", {})
            shiny_owned["JD-080"] = int(shiny_owned.get("JD-080", 0)) + 1
            cfg.set_value("collection", "shiny_owned", shiny_owned)
            cfg.set_value("trials", "sponsor_leader_unlocked", true)
            cfg.set_value("trials", "sponsor_sleeve_unlocked", true)
            special = "✦ Shiny The Sponsor Unlocked!"
        cfg.set_value("trials", "sponsor_defeated", true)
    cfg.set_value("trials", "pending_opponent", "")
    cfg.set_value("trials", "pending_tier", 0)
    cfg.save("user://journeys_dawn_profile.cfg")
    var out := {"gold": gold_awarded}
    if special != "":
        out["special"] = special
    return out

# Merges the {"gold":int, "packs":int, "special":String} dictionaries returned
# by the reward-granting functions above into the ordered list of lines the
# game-over screen displays -- gold and packs totalled into single lines,
# any one-off unlocks/bonuses listed individually beneath them.
func _combine_reward_lines(rewards: Array) -> Array:
    var total_gold := 0
    var total_packs := 0
    var specials: Array = []
    for reward in rewards:
        if not (reward is Dictionary):
            continue
        total_gold += int(reward.get("gold", 0))
        total_packs += int(reward.get("packs", 0))
        if reward.has("special"):
            specials.append(str(reward["special"]))
    var lines: Array = []
    if total_gold > 0:
        lines.append("+%d Gold" % total_gold)
    if total_packs > 0:
        lines.append("+%d Pack%s" % [total_packs, "" if total_packs == 1 else "s"])
    lines.append_array(specials)
    return lines

func show_game_over(title_text: String, subtitle: String, player_won: bool, rewards: Array = []) -> void:
    player_turn_active = false
    # _play_victory_sequence (the VICTORY/DEFEAT banner + sparkles + scrim) runs
    # on its own fixed timers and can still be mid-animation when this fires --
    # its bright banner and sparkles were competing for attention with the
    # freshly-faded-in result buttons underneath, which is exactly why the
    # buttons were hard to spot/click ("behind the victory screen"). Cut it off
    # immediately so the result screen is the only thing left on screen.
    # Invalidate any in-flight _play_victory_sequence FIRST -- this takes
    # effect immediately, unlike is_instance_valid(finish_layer), which stays
    # true until the end of the current frame even after queue_free(). That
    # gap was enough for the coroutine to slip in one more banner/backdrop
    # node on a slow frame, which is what could make the victory cinematic's
    # own "VICTORY" banner appear to bleed into this screen underneath.
    victory_sequence_token += 1
    if is_instance_valid(finish_layer):
        finish_layer.queue_free()
    # The result screen used to be shown on the shared `overlay` node, which
    # is also reused by mid-match modals (pass-device handoff, the strategic
    # collapse spell choice, etc). If one of those modals was ever left
    # active — or later toggled `overlay.visible` — it could hide or fight
    # over the same node as the victory/defeat screen, which is exactly what
    # "stuck on the victory screen, buttons don't do anything" looks like.
    # Give the result screen its own dedicated, disposable layer so nothing
    # else in the game can ever touch or hide it once it's up.
    if is_instance_valid(game_over_layer):
        game_over_layer.queue_free()
    game_over_layer = ColorRect.new()
    game_over_layer.color = Color(0, 0, 0, 0.68)
    game_over_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    game_over_layer.mouse_filter = Control.MOUSE_FILTER_STOP
    # Was 10000 -- Godot's CanvasItem z_index is capped at 4096 (see
    # CANVAS_ITEM_Z_MAX). Setting it out of range doesn't clamp, it fails the
    # engine's validation and prints "Tried to set Z index to an invalid
    # value" while silently leaving z_index at its previous/default value
    # (0). That's the real reason the result screen kept rendering *behind*
    # ordinary board UI (hand cards, amulet panels, popups) instead of on top
    # of everything -- it never actually got a high z_index at all, every
    # single time this ran. 4096 is the actual maximum, still higher than
    # every other layer in the game so it always wins.
    game_over_layer.z_index = 4096
    game_over_layer.modulate = Color(1, 1, 1, 0)
    if not safe_add_child(self, game_over_layer):
        return

    # The panel grows to fit an extra "REWARDS EARNED" section when the match
    # actually granted something (challenge/trial gold, packs, unlocks) --
    # empty-handed losses and practice matches keep the shorter, original
    # layout instead of showing an empty rewards block.
    var has_rewards := not rewards.is_empty()
    var panel_height := 460.0 if has_rewards else 400.0
    var panel_y := (720.0 - panel_height) * 0.5

    # A solid, high-contrast card behind the badge/title/buttons -- instead of
    # buttons floating directly on the translucent full-screen dim -- so the
    # result panel reads as one clear focal point instead of controls that
    # look stranded/half-hidden against whatever was on the board underneath.
    var card_panel := Panel.new()
    card_panel.position = Vector2(340, panel_y)
    card_panel.size = Vector2(600, panel_height)
    var card_style := StyleBoxFlat.new()
    card_style.bg_color = Color(0.035, 0.05, 0.09, 0.97)
    card_style.border_color = Color(1.0, 0.86, 0.32) if player_won else Color(0.6, 0.74, 1.0)
    card_style.set_border_width_all(3)
    card_style.set_corner_radius_all(20)
    card_style.shadow_color = Color(0, 0, 0, 0.6)
    card_style.shadow_size = 24
    card_panel.add_theme_stylebox_override("panel", card_style)
    game_over_layer.add_child(card_panel)

    var box := VBoxContainer.new()
    box.position = Vector2(350, panel_y + 20)
    box.size = Vector2(580, panel_height - 40)
    box.alignment = BoxContainer.ALIGNMENT_CENTER
    box.add_theme_constant_override("separation", 12)
    game_over_layer.add_child(box)

    var badge := Label.new()
    badge.text = "★" if player_won else "↻"
    badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    badge.add_theme_font_size_override("font_size", ui_font(64))
    badge.add_theme_color_override("font_color", Color(1.0, 0.86, 0.32) if player_won else Color(0.64, 0.78, 1.0))
    box.add_child(badge)

    var title := Label.new()
    title.text = title_text
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", ui_font(52))
    title.add_theme_color_override("font_color", Color(0.98, 0.84, 0.34) if player_won else Color(0.82, 0.90, 1.0))
    box.add_child(title)

    var sub := Label.new()
    sub.text = subtitle
    sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    sub.add_theme_font_size_override("font_size", ui_font(20))
    box.add_child(sub)

    if has_rewards:
        var rewards_panel := PanelContainer.new()
        var rewards_style := StyleBoxFlat.new()
        rewards_style.bg_color = Color(1.0, 0.86, 0.32, 0.10) if player_won else Color(0.6, 0.74, 1.0, 0.10)
        rewards_style.border_color = Color(1.0, 0.86, 0.32, 0.55) if player_won else Color(0.6, 0.74, 1.0, 0.55)
        rewards_style.set_border_width_all(1)
        rewards_style.set_corner_radius_all(10)
        rewards_style.content_margin_left = 18
        rewards_style.content_margin_right = 18
        rewards_style.content_margin_top = 10
        rewards_style.content_margin_bottom = 10
        rewards_panel.add_theme_stylebox_override("panel", rewards_style)
        box.add_child(rewards_panel)

        var rewards_box := VBoxContainer.new()
        rewards_box.alignment = BoxContainer.ALIGNMENT_CENTER
        rewards_box.add_theme_constant_override("separation", 4)
        rewards_panel.add_child(rewards_box)

        var rewards_header := Label.new()
        rewards_header.text = "REWARDS EARNED"
        rewards_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        rewards_header.add_theme_font_size_override("font_size", ui_font(15))
        rewards_header.add_theme_color_override("font_color", Color(0.7, 0.76, 0.86))
        rewards_box.add_child(rewards_header)

        for reward_line in rewards:
            var reward_label := Label.new()
            reward_label.text = str(reward_line)
            reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
            reward_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
            reward_label.add_theme_font_size_override("font_size", ui_font(19))
            reward_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55) if player_won else Color(0.86, 0.92, 1.0))
            rewards_box.add_child(reward_label)

    # Both buttons get explicit high-contrast styling. Every other button in
    # this UI is hand-styled with a StyleBoxFlat -- leaving these two on the
    # bare engine default made them look flat/washed out against the custom
    # dark theme everywhere else, which is what made them so easy to miss.
    var button := Button.new()
    button.text = "PLAY AGAIN"
    button.custom_minimum_size = Vector2(280, 58)
    button.focus_mode = Control.FOCUS_NONE
    button.add_theme_font_size_override("font_size", ui_font(19))
    var primary_style := StyleBoxFlat.new()
    primary_style.bg_color = Color(1.0, 0.86, 0.32)
    primary_style.set_corner_radius_all(12)
    button.add_theme_stylebox_override("normal", primary_style)
    button.add_theme_stylebox_override("hover", primary_style)
    button.add_theme_stylebox_override("pressed", primary_style)
    button.add_theme_color_override("font_color", Color(0.04, 0.06, 0.10))
    button.add_theme_color_override("font_hover_color", Color(0.04, 0.06, 0.10))
    button.add_theme_color_override("font_pressed_color", Color(0.04, 0.06, 0.10))
    button.pressed.connect(_restart_after_match)
    box.add_child(button)

    var home := Button.new()
    home.text = "RETURN TO MAIN MENU"
    home.custom_minimum_size = Vector2(280, 58)
    home.focus_mode = Control.FOCUS_NONE
    home.add_theme_font_size_override("font_size", ui_font(17))
    var secondary_style := StyleBoxFlat.new()
    secondary_style.bg_color = Color(0.12, 0.16, 0.26, 0.95)
    secondary_style.border_color = Color(0.6, 0.74, 1.0)
    secondary_style.set_border_width_all(2)
    secondary_style.set_corner_radius_all(12)
    home.add_theme_stylebox_override("normal", secondary_style)
    home.add_theme_stylebox_override("hover", secondary_style)
    home.add_theme_stylebox_override("pressed", secondary_style)
    home.add_theme_color_override("font_color", Color(0.86, 0.92, 1.0))
    home.pressed.connect(_return_to_main_menu)
    box.add_child(home)

    var fade := create_tween()
    fade.tween_property(game_over_layer, "modulate:a", 1.0, 0.22)

func _restart_after_match() -> void:
    if is_instance_valid(game_over_layer):
        game_over_layer.queue_free()
    game_over = false
    busy = false
    start_game()

func _return_to_main_menu() -> void:
    if is_instance_valid(game_over_layer):
        game_over_layer.queue_free()
    game_over = false
    busy = false
    # Signal menu.gd to skip the login screen and go straight to Home.
    var _nav := ConfigFile.new()
    _nav.set_value("nav", "return_from_battle", true)
    _nav.save("user://nav.cfg")
    var err := get_tree().change_scene_to_file("res://main.tscn")
    if err != OK:
        push_error("Could not return to main menu: %s" % err)

## ── Combat VFX helpers ────────────────────────────────────────────────────────

func _rarity_tier_int(rarity: String) -> int:
    match rarity:
        "Silver":    return 1
        "Gold":      return 2
        "Epic":      return 3
        "Legendary": return 4
        "Platinum":  return 5
    return 0

func _projectile_type_for_card(card: Dictionary) -> String:
    if bool(card.get("is_spell", false)):
        return "spell"
    var ability := str(card.get("ability", ""))
    if ability.contains("burn") or ability.contains("fire"):
        return "fire"
    if ability.contains("lightning") or ability.contains("storm"):
        return "lightning"
    match str(card.get("faction", card.get("class", ""))):
        "Courage": return "slash"
        "Hope":    return "energy"
        "Serenity":return "wave"
        "Purpose": return "punch"
    return "punch"

func _projectile_symbol(proj_type: String) -> String:
    match proj_type:
        "slash":     return "✕"
        "energy":    return "✦"
        "wave":      return "≋"
        "spell":     return "◆"
        "fire":      return "★"
        "lightning": return "✦"
        "punch":     return "●"
    return "●"

func _projectile_impact_color(proj_type: String, rarity: String) -> Color:
    var base: Color
    match proj_type:
        "slash":     base = Color(1.0, 0.36, 0.14)
        "energy":    base = Color(0.38, 0.76, 1.0)
        "wave":      base = Color(0.22, 0.90, 0.80)
        "spell":     base = Color(0.72, 0.32, 1.0)
        "fire":      base = Color(1.0, 0.52, 0.08)
        "lightning": base = Color(0.95, 0.98, 0.28)
        "punch":     base = Color(1.0, 0.68, 0.22)
        _:           base = Color(1.0, 0.85, 0.35)
    return base.lightened(_rarity_tier_int(rarity) * 0.06)

## Spawns a projectile that travels from `from_global` to `to_global`.
## Returns the travel duration so the caller can await it.
## Does NOT await internally — fire-and-forget.
func _launch_projectile(from_global: Vector2, to_global: Vector2, proj_type: String, rarity: String) -> float:
    var dist: float      = from_global.distance_to(to_global)
    var travel: float    = clampf(dist / 900.0, 0.14, 0.32)
    var rtier: int       = _rarity_tier_int(rarity)
    var base_col: Color  = _projectile_impact_color(proj_type, rarity)
    var proj_sz: float   = 11.0 + rtier * 3.5

    # ── Main projectile node ───────────────────────────────────────────────
    var proj := Panel.new()
    proj.size    = Vector2(proj_sz, proj_sz)
    proj.position = from_global - proj.size * 0.5
    proj.z_index = 850
    var pst := StyleBoxFlat.new()
    pst.bg_color   = base_col
    pst.set_corner_radius_all(int(proj_sz * 0.5))
    pst.shadow_color = base_col.lightened(0.35)
    pst.shadow_size  = 4 + rtier * 2
    proj.add_theme_stylebox_override("panel", pst)
    var sym := Label.new()
    sym.text = _projectile_symbol(proj_type)
    sym.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    sym.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    sym.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
    sym.add_theme_font_size_override("font_size", int(proj_sz * 0.85))
    sym.add_theme_color_override("font_color", Color.WHITE)
    sym.mouse_filter = Control.MOUSE_FILTER_IGNORE
    proj.add_child(sym)
    if not safe_add_child(self, proj):
        return travel

    # ── Ghost trail — count scales with graphics quality ──────────────────
    var trail_max := mini(2 + rtier, 6)
    var trail_count := maxi(0, int(float(trail_max) * ([0.25, 0.6, 1.0] as Array)[CardView.graphics_quality]))
    for _ti in range(trail_count):
        var t_frac := float(_ti + 1) / float(trail_count + 1)
        var g_pos: Vector2 = from_global.lerp(to_global, t_frac * 0.28)
        var g_sz: float    = proj_sz * (1.0 - t_frac * 0.5)
        var ghost := ColorRect.new()
        ghost.size  = Vector2(g_sz, g_sz)
        ghost.color = Color(base_col.r, base_col.g, base_col.b, 0.55 * (1.0 - t_frac * 0.45))
        ghost.position = g_pos - ghost.size * 0.5
        ghost.z_index  = 840
        ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
        if safe_add_child(self, ghost):
            var delay := travel * t_frac * 0.32
            var gtw := create_tween()
            gtw.tween_interval(delay)
            gtw.tween_property(ghost, "modulate:a", 0.0, travel * 0.55)
            get_tree().create_timer(delay + travel * 0.65, true, false, true).timeout.connect(
                func(): if is_instance_valid(ghost): ghost.queue_free())

    # ── Travel tween ───────────────────────────────────────────────────────
    var ptw := create_tween()
    # Cubic acceleration: projectile starts slow then rockets — feels more forceful.
    ptw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
    ptw.tween_property(proj, "position", to_global - proj.size * 0.5, travel)

    # Pre-impact brighten at 72% of travel — telegraphs the hit before it lands.
    get_tree().create_timer(travel * 0.72, true, false, true).timeout.connect(func():
        if not is_instance_valid(proj): return
        var brig := create_tween()
        brig.tween_property(proj, "modulate", Color(2.4, 2.4, 2.4), 0.06)
        brig.tween_property(proj, "modulate", Color.WHITE, 0.04))

    # Arrival burst: bigger pop, snappier fade
    get_tree().create_timer(travel - 0.04, true, false, true).timeout.connect(func():
        if not is_instance_valid(proj): return
        var burst := create_tween().set_parallel(true)
        burst.tween_property(proj, "scale",       Vector2(4.2 + rtier * 0.7, 4.2 + rtier * 0.7), 0.08)
        burst.tween_property(proj, "modulate:a",  0.0,                                             0.07))

    get_tree().create_timer(travel + 0.18, true, false, true).timeout.connect(
        func(): if is_instance_valid(proj): proj.queue_free())

    return travel

## Spawns `count` spark fragments flying outward from `at_global`.
func _spawn_impact_sparks(at_global: Vector2, color: Color, count: int) -> void:
    var q_scale: float = ([0.35, 0.65, 1.0] as Array)[CardView.graphics_quality]
    var actual := maxi(1, int(float(count) * q_scale))
    for _si in range(actual):
        var spark := ColorRect.new()
        var sz := randf_range(3.5, 7.5)
        spark.size     = Vector2(sz, sz)
        spark.color    = color.lightened(randf_range(-0.1, 0.35))
        spark.position = at_global - spark.size * 0.5
        spark.z_index  = 870
        spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
        if not safe_add_child(self, spark): continue
        var angle := float(_si) * TAU / float(count) + randf_range(-0.45, 0.45)
        var speed := randf_range(52.0, 140.0)
        var vel   := Vector2(cos(angle), sin(angle)) * speed
        var life  := randf_range(0.28, 0.55)
        var stw := create_tween().set_parallel(true)
        stw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        stw.tween_property(spark, "position",    at_global + vel * life - spark.size * 0.5, life)
        stw.tween_property(spark, "modulate:a",  0.0,                                       life)
        get_tree().create_timer(life + 0.06, true, false, true).timeout.connect(
            func(): if is_instance_valid(spark): spark.queue_free())

## Directional screen shake: first impulse toward `impact_dir`, then decaying random.
## Pass a non-zero impact_dir for the characteristic directional hit feel.
func _screen_shake(intensity: float, duration: float, impact_dir: Vector2 = Vector2.ZERO) -> void:
    if is_instance_valid(_shake_tween): _shake_tween.kill()
    var origin := Vector2.ZERO
    _shake_tween = create_tween()
    var steps := 8
    var step_t := duration / float(steps)
    var dir := impact_dir.normalized() if impact_dir.length() > 0.01 \
        else Vector2(randf_range(-1.0, 1.0), randf_range(-0.5, 0.5)).normalized()
    for i in range(steps):
        var decay := pow(1.0 - float(i) / float(steps), 1.4)
        var off: Vector2
        if i == 0:
            off = dir * intensity * decay           # first hit — toward impact
        elif i == 1:
            off = -dir * intensity * decay * 0.55  # rebound
        else:
            off = Vector2(randf_range(-1.0, 1.0), randf_range(-0.55, 0.55)).normalized() * intensity * decay
        _shake_tween.tween_property(self, "position", origin + off, step_t)
    _shake_tween.tween_property(self, "position", origin, step_t * 0.5)

## Expanding ring at impact point — shockwave feel on every hit.
func _spawn_impact_ring(at_global: Vector2, color: Color, rtier: int) -> void:
    if CardView.graphics_quality == 0: return
    var ring := Panel.new()
    var ring_sz := 28.0 + rtier * 9.0
    ring.size = Vector2(ring_sz, ring_sz)
    ring.position = at_global - ring.size * 0.5
    ring.z_index = 876
    ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ring.pivot_offset = ring.size * 0.5
    var rst := StyleBoxFlat.new()
    rst.bg_color = Color(0, 0, 0, 0)
    rst.border_color = color.lightened(0.30)
    rst.set_border_width_all(maxi(2, rtier + 1))
    rst.set_corner_radius_all(int(ring_sz * 0.5))
    ring.add_theme_stylebox_override("panel", rst)
    if not safe_add_child(self, ring): return
    var target_scale := 3.4 + rtier * 0.55
    var tw := create_tween().set_parallel(true)
    tw.tween_property(ring, "scale", Vector2(target_scale, target_scale), 0.34)
    tw.tween_property(ring, "modulate:a", 0.0, 0.30)
    tw.finished.connect(ring.queue_free)

## Bright central flash at the impact point — the pop of energy on contact.
func _spawn_impact_flash(at_global: Vector2, color: Color, rtier: int) -> void:
    var flash := Panel.new()
    var fsz := 30.0 + rtier * 11.0
    flash.size = Vector2(fsz, fsz)
    flash.position = at_global - flash.size * 0.5
    flash.z_index = 894
    flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
    flash.pivot_offset = flash.size * 0.5
    var fst := StyleBoxFlat.new()
    fst.bg_color = Color(minf(color.r * 2.2, 1.0), minf(color.g * 2.0, 1.0), minf(color.b * 2.0, 1.0), 0.94)
    fst.set_corner_radius_all(int(fsz * 0.5))
    flash.add_theme_stylebox_override("panel", fst)
    if not safe_add_child(self, flash): return
    var tw := create_tween().set_parallel(true)
    tw.tween_property(flash, "scale", Vector2(2.2 + rtier * 0.45, 2.2 + rtier * 0.45), 0.11)
    tw.tween_property(flash, "modulate:a", 0.0, 0.11)
    tw.finished.connect(flash.queue_free)

## Weighted damage number: pops large, springs to size, drifts up, fades.
## Fire-and-forget — do NOT await this. Combat continues while it animates.
func show_damage_number(dmg: int, world_pos: Vector2, attacker_rarity: String = "Bronze") -> void:
    var rtier := _rarity_tier_int(attacker_rarity)
    var is_heavy := dmg >= 5 or rtier >= 4
    var lbl := Label.new()
    lbl.text = "-%d" % dmg
    lbl.z_index = 1412
    lbl.add_theme_font_size_override("font_size", ui_font(50 if is_heavy else 38))
    lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.18) if is_heavy else Color(1.0, 0.26, 0.22))
    lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.92))
    lbl.add_theme_constant_override("shadow_offset_x", 3)
    lbl.add_theme_constant_override("shadow_offset_y", 3)
    lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
    lbl.pivot_offset = Vector2(30, 22)
    lbl.position = world_pos
    if not safe_add_child(self, lbl): return
    lbl.scale = Vector2(2.0, 2.0)  # starts large
    var tw := create_tween()
    # Spring bounce to natural size
    tw.tween_property(lbl, "scale", Vector2(1.0, 1.0), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tw.parallel().tween_property(lbl, "position:y", world_pos.y - 10, 0.14)
    # Drift upward
    tw.tween_property(lbl, "position:y", world_pos.y - 68, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    # Fade after short hold
    tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.58).set_delay(0.16)
    get_tree().create_timer(0.90, true, false, true).timeout.connect(
        func(): if is_instance_valid(lbl): lbl.queue_free())

## Floating "+N/+N" text rising off a card + brief scale-pop on the card itself.
## Call anywhere a live board follower gets a permanent stat increase.
func show_buff_flash(card_view: CardView, stat_text: String, color: Color) -> void:
    if not is_instance_valid(card_view):
        return
    card_view.play_buff_vfx(stat_text, color)
    # Floating label drifts up from the card centre so it clears any board UI.
    var lbl := Label.new()
    lbl.text = stat_text
    lbl.z_index = 1600
    lbl.add_theme_font_size_override("font_size", ui_font(22))
    lbl.add_theme_color_override("font_color", color)
    lbl.add_theme_color_override("font_shadow_color", Color.BLACK)
    lbl.add_theme_constant_override("shadow_offset_x", 2)
    lbl.add_theme_constant_override("shadow_offset_y", 2)
    lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var start_pos := card_view.global_position + Vector2(card_view.size.x * 0.5 - 24, -8)
    lbl.position = start_pos
    if not safe_add_child(self, lbl): return
    var tw := create_tween().set_parallel(true)
    tw.tween_property(lbl, "position:y", start_pos.y - 42, 0.80)
    tw.tween_property(lbl, "modulate:a", 0.0, 0.65).set_delay(0.22)
    tw.finished.connect(lbl.queue_free)

## Upward-drifting heart particles for leader healing VFX.
func _spawn_heal_particles(origin: Vector2) -> void:
    var count := 5 if CardView.graphics_quality >= 2 else 3
    for i in range(count):
        var p := Label.new()
        p.text = "♥"
        p.add_theme_font_size_override("font_size", ui_font(13 + (i % 3) * 4))
        p.add_theme_color_override("font_color", Color(0.42, 1.0, 0.62, 0.90))
        p.z_index = 650
        p.mouse_filter = Control.MOUSE_FILTER_IGNORE
        p.position = origin + Vector2(randf_range(-24, 24), randf_range(-10, 10))
        if not safe_add_child(self, p): continue
        var dest := Vector2(p.position.x + randf_range(-16, 16), p.position.y - randf_range(42, 72))
        var tw := create_tween().set_parallel(true)
        tw.tween_property(p, "position", dest, 0.72)
        tw.tween_property(p, "modulate:a", 0.0, 0.68).set_delay(0.10)
        tw.finished.connect(p.queue_free)

## Dark wisp that drifts toward the relapse zone when a follower is destroyed.
func _spawn_relapse_entry_vfx(origin: Vector2, player_side: bool) -> void:
    if CardView.graphics_quality == 0:
        return
    var ghost := Label.new()
    ghost.text = "↓"
    ghost.add_theme_font_size_override("font_size", ui_font(20))
    ghost.add_theme_color_override("font_color", Color(0.55, 0.42, 0.72, 0.80))
    ghost.z_index = 520
    ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ghost.position = origin
    if not safe_add_child(self, ghost): return
    var drift_y := origin.y + (58.0 if player_side else -58.0)
    var tw := create_tween().set_parallel(true)
    tw.tween_property(ghost, "position:y", drift_y, 0.60)
    tw.tween_property(ghost, "modulate:a", 0.0, 0.55).set_delay(0.08)
    tw.finished.connect(ghost.queue_free)

func show_vfx(text_value: String, world_pos: Vector2, color: Color) -> void:
    var label := Label.new(); label.text = text_value; label.position = world_pos; label.z_index = 900; label.add_theme_font_size_override("font_size", ui_font(31)); label.add_theme_color_override("font_color", color); label.add_theme_color_override("font_shadow_color", Color.BLACK); label.add_theme_constant_override("shadow_offset_x", 3); label.add_theme_constant_override("shadow_offset_y", 3)
    if not safe_add_child(self, label): return
    var tween := create_tween().set_parallel(true); tween.tween_property(label, "position:y", world_pos.y - 55, 0.55); tween.tween_property(label, "modulate:a", 0.0, 0.55)
    # Was `await tween.finished` -- if this tween is ever interrupted (its
    # target label freed, or fighting another tween on the same property)
    # that signal never fires, and every caller that awaits show_vfx hangs
    # forever. _play_victory_sequence awaits this for the DEFEATED popup
    # *before* it ever builds the scrim/backdrop/banner, so a single stuck
    # frame here silently skipped the entire victory screen dimming and left
    # only whatever got drawn earlier floating over a fully-lit board. Await
    # a fixed timer matching the tween's own duration instead, same fix as
    # every other tween.finished hang in this file.
    await get_tree().create_timer(0.55, true, false, true).timeout
    if is_instance_valid(label): label.queue_free()

func refresh_ui(animate_new: bool = false, new_index: int = -1, new_player_side: bool = true) -> void:
    if not game_over:
        if not player_low_health_barked and player_health > 0 and player_health <= BATTLE_BARK_HEALTH_THRESHOLD:
            player_low_health_barked = true
            play_battle_bark(player_leader, selected_class, "low_health", true, true)
        if not enemy_low_health_barked and enemy_health > 0 and enemy_health <= BATTLE_BARK_HEALTH_THRESHOLD:
            enemy_low_health_barked = true
            play_battle_bark(enemy_leader, enemy_class, "low_health", false, true)
    safe_set_text(player_health_label, "♥ %d" % player_health); safe_set_text(enemy_health_label, "♥ %d" % enemy_health)
    safe_set_text(mana_label, "%d / %d" % [player_mana, player_max_mana])
    for i in range(pp_pips.size()):
        var pip: ColorRect = pp_pips[i]
        if i < player_mana:
            pip.color = Color(0.25, 0.82, 1.0, 1.0)
        elif i < player_max_mana:
            pip.color = Color(0.16, 0.34, 0.46, 1.0)
        else:
            pip.color = Color(0.055, 0.09, 0.12, 0.9)
    safe_set_text(turn_label, "TURN %d" % turn_number)
    safe_set_text(hand_count_label, "HAND  %d/%d" % [player_hand.size(), MAX_HAND])
    var evolutions_left := 0
    for used in player_evolutions_used:
        if not used:
            evolutions_left += 1
    safe_set_text(evolution_count_label, "%d/%d EVOLUTIONS LEFT" % [evolutions_left, player_evolutions_used.size()])
    safe_set_text(momentum_button, "MOMENTUM\n%d CHARGE%s" % [player_momentum, "" if player_momentum == 1 else "S"])
    safe_set_disabled(momentum_button, not player_turn_active or momentum_used_this_turn or player_momentum <= 0 or busy or game_over)
    safe_set_text(momentum_label, "Opponent Momentum: %d" % enemy_momentum)
    if is_instance_valid(end_turn_button):
        end_turn_button.disabled = game_over or busy or not player_turn_active
    update_dynamic_music()
    var active_music: AudioStreamPlayer = music_player_alt if music_using_alt else music_player
    if is_instance_valid(active_music) and not active_music.playing and current_music != "":
        var restart_track := current_music
        current_music = ""
        set_battle_music(restart_track)
    for i in range(evolution_buttons.size()):
        var evolution_button: Button = evolution_buttons[i]
        if not is_instance_valid(evolution_button):
            continue
        evolution_button.disabled = game_over or busy or player_evolutions_used[i] or player_mana < (i + 1) or player_board.is_empty() or not player_turn_active or turn_number < 4
        if player_evolutions_used[i]:
            # Spent rune: gone cold — checkmark stays, glow and scale drop out.
            evolution_button.text = "✓\n%d" % (i + 1)
            evolution_button.modulate = Color(0.42, 0.45, 0.5, 0.75)
            evolution_button.scale = Vector2.ONE
        else:
            evolution_button.text = "%s\n%d" % ["★".repeat(i + 1), i + 1]
            evolution_button.modulate = Color.WHITE if not evolution_button.disabled else Color(0.62, 0.65, 0.7, 0.55)
    rebuild_hand(); rebuild_enemy_hand()
    rebuild_board(player_board_area, player_board, true, animate_new and new_player_side, new_index)
    rebuild_board(enemy_board_area, enemy_board, false, animate_new and not new_player_side, new_index)
    rebuild_amulet_row(player_amulet_area, player_board, true)
    rebuild_amulet_row(enemy_amulet_area, enemy_board, false)

func rebuild_hand() -> void:
    clear_children(player_hand_area)
    var count: int = player_hand.size()
    var width: float = 142.0
    var spacing: float = minf(104.0, 760.0 / float(maxi(1, count)))
    var total: float = width + spacing * float(maxi(0, count - 1))
    var start_x: float = (player_hand_area.size.x - total) * 0.5
    for i in range(count):
        var view := CardView.new()
        var inspect_card: Dictionary = player_hand[i].duplicate(true)
        inspect_card["_ui_context"] = "hand"
        inspect_card["_ui_index"] = i
        view.setup(inspect_card, i, false, false)
        view.position = Vector2(start_x + i * spacing, 12)
        view.scale = Vector2(0.78, 0.78)
        view.base_position = view.position
        view.card_chosen.connect(play_card)
        view.drag_action_requested.connect(_on_card_drag_action)
        view.inspect_requested.connect(show_card_details)
        player_hand_area.add_child(view)
        view.enable_card_interactions(true, true)

func reorder_hand_card(from_index: int, to_index: int) -> void:
    if busy or game_over:
        return
    if from_index < 0 or from_index >= player_hand.size() or to_index < 0 or to_index >= player_hand.size():
        return
    if from_index == to_index:
        return
    var moved_card: Dictionary = player_hand.pop_at(from_index)
    var insert_index: int = to_index
    if from_index < to_index:
        insert_index -= 1
    player_hand.insert(clampi(insert_index, 0, player_hand.size()), moved_card)
    safe_set_text(status_label, "Hand rearranged. Drag any card onto another card to reorder it.")
    rebuild_hand()

func set_battle_card_controls_visible(value: bool) -> void:
    for area in [player_hand_area, player_board_area, enemy_board_area]:
        if not is_instance_valid(area): continue
        for child in area.get_children():
            if child is CardView:
                child.set_inspect_controls_visible(value)

func show_card_details(card_data: Dictionary) -> void:
    # Long-press inspection uses a compact solid side panel. It never changes
    # gameplay state and never provides Play/Attack buttons.
    close_card_details()
    card_detail_panel = Panel.new()
    card_detail_panel.position = Vector2(get_viewport_rect().size.x - 390.0, 92.0)
    card_detail_panel.size = Vector2(360.0, 500.0)
    # Was 5000 -- over Godot's CanvasItem z_index cap of 4096, which silently
    # fails to apply (see the game_over_layer fix for the full explanation).
    card_detail_panel.z_index = 4090
    card_detail_panel.mouse_filter = Control.MOUSE_FILTER_STOP
    var panel_style := StyleBoxFlat.new()
    panel_style.bg_color = Color(0.018, 0.032, 0.060, 0.985)
    panel_style.border_color = Color(0.92, 0.75, 0.30, 0.95)
    panel_style.set_border_width_all(3)
    panel_style.set_corner_radius_all(18)
    card_detail_panel.add_theme_stylebox_override("panel", panel_style)
    add_child(card_detail_panel)

    var preview := CardView.new()
    preview.setup(card_data.duplicate(true), -1, false, false)
    preview.position = Vector2(109, 24)
    preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
    card_detail_panel.add_child(preview)

    var title := Label.new()
    title.text = str(card_data.get("name", "Card"))
    title.position = Vector2(24, 222)
    title.size = Vector2(312, 42)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", ui_font(23))
    title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.42))
    card_detail_panel.add_child(title)

    var type_line := Label.new()
    var type_text := "RECOVERY SKILL" if bool(card_data.get("is_amulet", false)) else "%s • %s/%s" % [str(card_data.get("faction", card_data.get("class", "Neutral"))), str(card_data.get("attack", 0)), str(card_data.get("health", 0))]
    type_line.text = "%d PP • %s • %s" % [int(card_data.get("cost", 0)), str(card_data.get("rarity", "Bronze")), type_text]
    type_line.position = Vector2(24, 265)
    type_line.size = Vector2(312, 30)
    type_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    type_line.add_theme_font_size_override("font_size", ui_font(15))
    card_detail_panel.add_child(type_line)

    var rules := Label.new()
    rules.text = str(card_data.get("display_text", card_data.get("text", "No additional effect.")))
    rules.position = Vector2(28, 307)
    rules.size = Vector2(304, 112)
    rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    rules.vertical_alignment = VERTICAL_ALIGNMENT_TOP
    rules.add_theme_font_size_override("font_size", ui_font(16))
    card_detail_panel.add_child(rules)

    var hint := Label.new()
    hint.text = "Hold to read • Drag to play or attack"
    hint.position = Vector2(30, 422)
    hint.size = Vector2(300, 25)
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.modulate = Color(0.72, 0.82, 0.92)
    hint.add_theme_font_size_override("font_size", ui_font(12))
    card_detail_panel.add_child(hint)

    var close := Button.new()
    close.text = "CLOSE"
    close.position = Vector2(100, 454)
    close.size = Vector2(160, 36)
    close.focus_mode = Control.FOCUS_NONE
    close.pressed.connect(close_card_details)
    card_detail_panel.add_child(close)

func close_card_details() -> void:
    if is_instance_valid(card_detail_panel):
        card_detail_panel.queue_free()
    card_detail_panel = null

## ── Survive-buff ability trigger ─────────────────────────────────────────────
## Called after both destroy_unit passes in resolve_combat so that a unit
## that died in that exchange never receives its own buff.
## was_attacker: true = this unit initiated the attack, false = it was the target.
func _check_survive_buff(board: Array, index: int, unit_player_side: bool, damage_taken: int, was_attacker: bool) -> void:
    if index < 0 or index >= board.size():
        return
    var unit: Dictionary = board[index]
    var ab := str(unit.get("ability", ""))
    var uid := str(unit.get("id", ""))
    var uname := str(unit.get("name", "?"))
    var atk_gain := 0
    var hp_gain := 0

    # Silver Never Quit (hardcoded ability) or pack-pulled JD-023
    if ab == "survive_buff" or uid == "JD-023":
        atk_gain = 1; hp_gain = 1
    # First Brave Step JD-089: +1 Health after surviving combat
    elif uid == "JD-089":
        atk_gain = 0; hp_gain = 1
    # Gold Never Quit JD-146: +1/+0 only when it takes damage as the defender
    elif uid == "JD-146" and not was_attacker:
        atk_gain = 1; hp_gain = 0

    if atk_gain == 0 and hp_gain == 0:
        return

    unit["attack"] = int(unit.get("attack", 0)) + atk_gain
    unit["health"] = int(unit.get("health", 0)) + hp_gain
    if hp_gain > 0:
        unit["max_health"] = int(unit.get("max_health", unit["health"])) + hp_gain
    board[index] = unit

    print("SURVIVE BUFF ── %s (%s) took %d dmg, survived — +%d/+%d applied → atk=%d hp=%d" % [
        uname, uid if uid != "" else ab, damage_taken, atk_gain, hp_gain,
        int(unit["attack"]), int(unit["health"])])

    var buff_str := "+%d/+%d" % [atk_gain, hp_gain] if (atk_gain > 0 and hp_gain > 0) \
        else ("+%d ATK" % atk_gain if hp_gain == 0 else "+%d HP" % hp_gain)
    var area: Control = player_board_area if unit_player_side else enemy_board_area
    show_buff_flash(find_card_view_for_board_index(area, index), buff_str, Color(1.0, 0.85, 0.25))
    await show_vfx(buff_str, area.global_position + Vector2(90 + index * 145, -20), Color(1.0, 0.85, 0.25))

## ── Attack drag-line overlay ──────────────────────────────────────────────────
func _ensure_attack_drag_line() -> void:
    if is_instance_valid(attack_drag_line):
        return
    attack_drag_line = Line2D.new()
    attack_drag_line.width = 3.5
    attack_drag_line.default_color = Color(1.0, 0.28, 0.18, 0.80)
    attack_drag_line.z_index = 1000
    attack_drag_line.visible = false
    safe_add_child(self, attack_drag_line)

func _on_attack_drag_update(card_index: int, _context: String, global_pos: Vector2) -> void:
    if game_over or busy or not player_turn_active:
        _clear_attack_drag()
        return
    if card_index < 0 or card_index >= player_board.size():
        _clear_attack_drag()
        return
    if not bool(player_board[card_index].get("can_attack", false)):
        _clear_attack_drag()
        return
    attack_drag_attacker_idx = card_index
    _ensure_attack_drag_line()

    # Start point: centre of attacker card in scene coordinates.
    var attacker_view: CardView = find_card_view_for_board_index(player_board_area, card_index)
    var start: Vector2 = global_pos  # fallback
    if is_instance_valid(attacker_view):
        start = attacker_view.global_position + attacker_view.size * attacker_view.scale * 0.5
    attack_drag_line.clear_points()
    attack_drag_line.add_point(start)
    attack_drag_line.add_point(global_pos)
    attack_drag_line.visible = true

    # Highlight the exact target under the pointer; dim invalid targets.
    var guard_idx: int = first_guard_index(enemy_board)
    for child in enemy_board_area.get_children():
        if not (child is CardView):
            continue
        var is_valid: bool = (guard_idx < 0 or child.card_index == guard_idx) \
            and not bool(enemy_board[mini(child.card_index, enemy_board.size() - 1)].get("is_amulet", false))
        if not is_valid:
            child.modulate = Color(0.50, 0.50, 0.50)
        else:
            var hovered: bool = Rect2(child.global_position, child.size * child.scale).grow(8.0).has_point(global_pos)
            child.modulate = Color(1.55, 1.25, 0.55) if hovered else Color(1.0, 1.0, 1.0)
    if is_instance_valid(enemy_leader):
        if guard_idx >= 0:
            enemy_leader.modulate = Color(0.50, 0.50, 0.50)
        else:
            var lhov: bool = Rect2(enemy_leader.global_position, enemy_leader.size).has_point(global_pos)
            enemy_leader.modulate = Color(1.55, 0.65, 0.65) if lhov else Color(1.0, 1.0, 1.0)

func _clear_attack_drag() -> void:
    attack_drag_attacker_idx = -1
    if is_instance_valid(attack_drag_line):
        attack_drag_line.visible = false
        attack_drag_line.clear_points()
    # Restore all enemy card and leader modulates.
    for child in enemy_board_area.get_children():
        if child is CardView:
            child.modulate = Color.WHITE
    if is_instance_valid(enemy_leader):
        enemy_leader.modulate = Color.WHITE

func _on_card_drag_action(card_index: int, context: String, release_global: Vector2) -> void:
    close_card_details()
    _clear_attack_drag()
    if busy or game_over or not player_turn_active:
        return
    if context == "hand":
        if is_instance_valid(player_board_area) and player_board_area.get_global_rect().has_point(release_global):
            play_card(card_index)
            return
        if is_instance_valid(player_amulet_area) and player_amulet_area.get_global_rect().has_point(release_global):
            play_card(card_index)
            return
        # Dropped back onto another card still in hand: reorder instead of
        # playing it (mirrors the old "drag onto another card" convention).
        if is_instance_valid(player_hand_area):
            for child in player_hand_area.get_children():
                if child is CardView and child.card_index != card_index and child.get_global_rect().has_point(release_global):
                    reorder_hand_card(card_index, child.card_index)
                    return
        return
    elif context == "player_board":
        if card_index < 0 or card_index >= player_board.size():
            return
        if bool(player_board[card_index].get("is_amulet", false)):
            safe_set_text(status_label, "Recovery Skills cannot attack.")
            return
        if not bool(player_board[card_index].get("can_attack", false)):
            safe_set_text(status_label, "%s is resting." % str(player_board[card_index].get("name", "That follower")))
            return
        # ── Target resolution ────────────────────────────────────────────────────
        # release_global is in canvas coordinates. card_view.gd touch path now
        # uses get_global_mouse_position() (canvas coords) so mouse and touch are
        # consistent with Control.get_global_rect() / global_position.
        # Step 1: enemy follower directly under the release point.
        # Use visual rect (size * scale) so the hit zone matches what's drawn.
        for child in enemy_board_area.get_children():
            if not (child is CardView):
                continue
            var vis: Rect2 = Rect2(child.global_position, child.size * child.scale).grow(12.0)
            if vis.has_point(release_global):
                print("[ATTACK RELEASE] pointer=%s type=follower id=%s node=%s" % [
                    release_global, child.data.get("id", "?"), child.get_path()])
                _drag_attack_pending = true
                selected_attacker = card_index
                card_clicked(child.card_index, false)
                _drag_attack_pending = false
                return
        # Step 2: enemy leader — exact rect, no grow, so it never bleeds into
        # the follower zone above it.
        if is_instance_valid(enemy_leader):
            var lr: Rect2 = Rect2(enemy_leader.global_position, enemy_leader.size)
            if lr.has_point(release_global):
                print("[ATTACK RELEASE] pointer=%s type=leader" % release_global)
                _drag_attack_pending = true
                selected_attacker = card_index
                leader_clicked(false)
                _drag_attack_pending = false
                return
        # Step 3: no valid target — cancel without attacking anything.
        print("[ATTACK RELEASE] pointer=%s cancelled=true" % release_global)
        safe_set_text(status_label, "Drag onto an enemy follower or the enemy leader to attack.")

func rebuild_enemy_hand() -> void:
    clear_children(enemy_hand_area)
    var count: int = enemy_hand.size()
    var spacing: float = minf(46.0, 460.0 / float(maxi(1, count)))
    var start_x: float = (enemy_hand_area.size.x - (126.0 + spacing * float(maxi(0, count - 1)))) * 0.5
    for i in range(count):
        var view := CardView.new(); view.setup({}, i, true, true); view.scale = Vector2(0.58,0.58); view.position = Vector2(start_x + i * spacing, 0); view.rotation = deg_to_rad((i - count / 2.0) * 2.0); enemy_hand_area.add_child(view)

func rebuild_board(area: Control, board: Array, player_side: bool, animate_new: bool, new_index: int) -> void:
    if not is_instance_valid(area):
        return
    clear_children(area)
    # Battlefield followers use the full card layout at a reduced scale. The old
    # compact layout could collapse visually on Android after viewport scaling.
    var gap: float = 18.0
    var available_width: float = maxf(1.0, area.size.x - 12.0)
    var desired_width: float = 5.0 * 142.0 + 4.0 * gap
    var visual_scale: float = minf(0.78, available_width / desired_width)
    visual_scale = maxf(0.58, visual_scale)
    var card_w: float = 142.0 * visual_scale
    var followers: Array = []
    var original_indices: Array = []
    for board_index in range(board.size()):
        if not bool(board[board_index].get("is_amulet", false)):
            followers.append(board[board_index])
            original_indices.append(board_index)
    var total: float = float(followers.size()) * card_w + float(maxi(0, followers.size() - 1)) * gap
    var start_x: float = (area.size.x - total) * 0.5
    for i in range(followers.size()):
        var original_index: int = int(original_indices[i])
        var view := CardView.new()
        var inspect_card: Dictionary = followers[i].duplicate(true)
        inspect_card["_ui_context"] = "player_board" if player_side else "enemy_board"
        inspect_card["_ui_index"] = original_index
        view.setup(inspect_card, original_index, false, false)
        view.scale = Vector2(visual_scale, visual_scale)
        view.position = Vector2(start_x + i * (card_w + gap), 0)
        view.base_position = view.position
        view.visible = true
        view.modulate = Color.WHITE
        view.z_index = 10 + i
        view.mouse_filter = Control.MOUSE_FILTER_STOP
        view.card_chosen.connect(func(idx: int): card_clicked(idx, player_side))
        if player_side:
            view.drag_action_requested.connect(_on_card_drag_action)
            view.drag_position_updated.connect(_on_attack_drag_update)
        view.inspect_requested.connect(show_card_details)
        area.add_child(view)
        view.enable_card_interactions(false, true)
        if player_side and original_index == selected_attacker:
            view.set_selected(true)
        if animate_new and original_index == new_index:
            view.summon_animation()

func rebuild_amulet_row(area: Control, board: Array, player_side: bool) -> void:
    if not is_instance_valid(area):
        return
    clear_children(area)
    var amulets: Array = []
    var indices: Array = []
    for i in range(board.size()):
        if bool(board[i].get("is_amulet", false)):
            amulets.append(board[i])
            indices.append(i)
    var slot_width := 168.0
    for slot in range(3):
        var holder := Panel.new()
        holder.position = Vector2(slot * 182.0, 2)
        holder.size = Vector2(slot_width, 72)
        area.add_child(holder)
        if slot < amulets.size():
            var accent := class_accent_color(str(amulets[slot].get("faction", amulets[slot].get("class", ""))))
            var st := StyleBoxFlat.new()
            st.bg_color = Color(0.045, 0.065, 0.10, 0.92)
            st.border_color = accent
            st.set_border_width_all(2)
            st.set_corner_radius_all(10)
            st.shadow_color = Color(0, 0, 0, 0.4)
            st.shadow_size = 4
            holder.add_theme_stylebox_override("panel", st)

            var accent_bar := ColorRect.new(); accent_bar.position = Vector2(0, 0); accent_bar.size = Vector2(4, slot_width * 0 + 52); accent_bar.color = accent; accent_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
            holder.add_child(accent_bar)

            var name_label := Label.new()
            name_label.text = str(amulets[slot].get("name", "Amulet"))
            name_label.position = Vector2(10, 4)
            name_label.size = Vector2(slot_width - 18, 22)
            name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
            name_label.add_theme_font_size_override("font_size", ui_font(12))
            name_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.97))
            name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
            holder.add_child(name_label)

            var tag := Label.new()
            tag.text = "RECOVERY SKILL"
            tag.position = Vector2(10, 26)
            tag.size = Vector2(slot_width - 18, 18)
            tag.add_theme_font_size_override("font_size", ui_font(9))
            tag.add_theme_color_override("font_color", accent.lightened(0.25))
            tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
            holder.add_child(tag)

            # Invisible hover target — lets mouse enter so tooltip fires.
            # Must NOT be disabled (disabled nodes eat no mouse events in Godot 4).
            # Effect text shown permanently — tooltip approach was unreliable.
            var effect_text := str(amulets[slot].get("display_text", ""))
            if not effect_text.is_empty():
                var fx_lbl := Label.new()
                fx_lbl.text = effect_text
                fx_lbl.position = Vector2(8, 44)
                fx_lbl.size = Vector2(slot_width - 14, 26)
                fx_lbl.add_theme_font_size_override("font_size", ui_font(8))
                fx_lbl.add_theme_color_override("font_color", Color(0.76, 0.82, 0.95))
                fx_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
                fx_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
                holder.add_child(fx_lbl)
        else:
            # Empty slot — hide entirely so the battlefield center stays clean.
            holder.visible = false

func clear_children(node: Node) -> void:
    for child in node.get_children():
        node.remove_child(child)
        child.queue_free()

func svg_texture(svg: String) -> Texture2D:
    var image := Image.new(); image.load_svg_from_string(svg, 1.0); return ImageTexture.create_from_image(image)

func refresh_battlefield_theme() -> void:
    if is_instance_valid(battlefield_background):
        battlefield_background.texture = svg_texture(battlefield_svg())

func battlefield_svg() -> String:
    # Strongly differentiated host arenas. The active player's selected deck class
    # controls the visual identity, and refresh_battlefield_theme() reapplies it
    # after battle setup is loaded.
    var sky_top := "#17354e"
    var sky_mid := "#0b2031"
    var floor_a := "#102d37"
    var floor_b := "#061720"
    var accent := "#75d1d5"
    var glow := "#f7e7a6"
    var scenery := ""
    var class_title := selected_class.to_upper()
    match selected_class:
        "Hope":
            sky_top = "#523566"; sky_mid = "#d67a4d"; floor_a = "#45243e"; floor_b = "#160d1c"; accent = "#ffd36f"; glow = "#fff1ad"
            scenery = "<circle cx='1040' cy='135' r='82' fill='#ffe49a' opacity='.55'/><path d='M0 320 Q170 245 330 315 T650 310 T980 315 T1280 295 V430 H0 Z' fill='#40203d' opacity='.82'/><rect x='525' y='185' width='230' height='125' rx='12' fill='#f6d49a' opacity='.18'/><text x='640' y='260' text-anchor='middle' fill='#ffe7a4' opacity='.72' font-size='46' font-family='sans-serif' font-weight='bold'>HOPE</text><path d='M570 310 V210 M710 310 V210' stroke='#ffd77b' stroke-width='9' opacity='.30'/>"
        "Purpose":
            sky_top = "#0d3459"; sky_mid = "#147c96"; floor_a = "#123b4b"; floor_b = "#06191e"; accent = "#f0ba45"; glow = "#d8f4ff"
            scenery = "<path d='M0 315 L155 225 L300 315 L460 190 L620 315 L790 210 L950 315 L1120 225 L1280 315 V430 H0 Z' fill='#0a2938' opacity='.86'/><path d='M115 295 V155 H130 V295 M130 165 H305 M285 165 V295' stroke='#f0c25c' stroke-width='10' opacity='.34'/><path d='M985 295 V150 H1000 V295 M1000 160 H1180 M1160 160 V295' stroke='#f0c25c' stroke-width='10' opacity='.34'/><circle cx='640' cy='155' r='58' fill='#d8f4ff' opacity='.13'/><path d='M610 155 H670 M640 125 V185' stroke='#f0ba45' stroke-width='8' opacity='.42'/>"
        "Serenity":
            sky_top = "#0e445d"; sky_mid = "#24a4a1"; floor_a = "#123e49"; floor_b = "#061a21"; accent = "#72eee6"; glow = "#e6ffff"
            scenery = "<circle cx='965' cy='128' r='72' fill='#eaffff' opacity='.40'/><path d='M0 280 L150 145 L300 280 L470 120 L650 285 L830 140 L1010 280 L1160 165 L1280 280 V360 H0 Z' fill='#123a4a' opacity='.78'/><path d='M0 315 Q180 275 360 315 T720 315 T1080 315 T1440 315 V430 H0 Z' fill='#75e7eb' opacity='.18'/><path d='M0 345 Q210 320 420 345 T840 345 T1260 345' fill='none' stroke='#b8ffff' stroke-width='5' opacity='.28'/><circle cx='640' cy='245' r='46' fill='none' stroke='#8bf3ed' stroke-width='6' opacity='.30'/><path d='M595 245 Q640 190 685 245 Q640 300 595 245' fill='#8bf3ed' opacity='.13'/>"
        "Courage":
            sky_top = "#4d1725"; sky_mid = "#ce4d32"; floor_a = "#49212a"; floor_b = "#180b10"; accent = "#ff633d"; glow = "#ffd4a1"
            scenery = "<path d='M0 300 L175 120 L315 300 L485 80 L650 300 L805 105 L975 300 L1130 135 L1280 300 V430 H0 Z' fill='#251018' opacity='.92'/><path d='M905 55 L835 175 L920 145 L855 275' fill='none' stroke='#fff0c4' stroke-width='13' opacity='.72'/><path d='M235 275 L640 170 L1045 275' fill='none' stroke='#ff754e' stroke-width='10' opacity='.22'/><path d='M575 305 L640 195 L705 305' fill='#ff6d42' opacity='.18'/><circle cx='640' cy='180' r='65' fill='#ff9a56' opacity='.16'/>"
    return """<svg xmlns='http://www.w3.org/2000/svg' width='1280' height='720'>
    <defs>
      <linearGradient id='sky' x2='0' y2='1'><stop stop-color='%s'/><stop offset='.58' stop-color='%s'/><stop offset='1' stop-color='#040911'/></linearGradient>
      <radialGradient id='sun'><stop stop-color='%s' stop-opacity='.72'/><stop offset='1' stop-color='%s' stop-opacity='0'/></radialGradient>
      <radialGradient id='arena'><stop stop-color='%s'/><stop offset='.70' stop-color='%s'/><stop offset='1' stop-color='%s'/></radialGradient>
      <filter id='glow'><feGaussianBlur stdDeviation='11'/></filter>
    </defs>
    <rect width='1280' height='720' fill='url(#sky)'/>
    <circle cx='640' cy='125' r='190' fill='url(#sun)'/>
    %s
    <ellipse cx='640' cy='400' rx='520' ry='222' fill='%s' opacity='.16' filter='url(#glow)'/>
    <ellipse cx='640' cy='400' rx='490' ry='198' fill='url(#arena)' stroke='%s' stroke-opacity='.92' stroke-width='6'/>
    <ellipse cx='640' cy='400' rx='430' ry='151' fill='none' stroke='%s' stroke-opacity='.38' stroke-width='3'/>
    <path d='M225 315 H1055 M225 490 H1055' stroke='%s' stroke-opacity='.48' stroke-width='4'/>
    <circle cx='640' cy='403' r='82' fill='none' stroke='%s' stroke-opacity='.34' stroke-width='12'/>
    <circle cx='640' cy='403' r='48' fill='none' stroke='%s' stroke-opacity='.32' stroke-width='4'/>
    <path d='M640 366 L672 422 L608 422 Z' fill='none' stroke='%s' stroke-opacity='.30' stroke-width='3' stroke-linejoin='round'/>
    <text x='640' y='690' text-anchor='middle' fill='%s' opacity='.34' font-size='16' font-family='sans-serif' font-weight='bold' letter-spacing='4'>ONE DAY AT A TIME</text>
    <text x='640' y='710' text-anchor='middle' fill='%s' opacity='.22' font-size='16' font-family='sans-serif' font-weight='bold'>%s ARENA</text>
    </svg>""" % [sky_top, sky_mid, glow, glow, floor_a, floor_a, floor_b, scenery, accent, accent, glow, accent, glow, accent, glow, accent, accent, class_title]

# frozen_string_literal: true

require "rainbow/refinement"

require_relative "valid_fields"

using Rainbow

# Controls all score logic and calculation, and does most of the directing 
# for the game.
class ScoreSheet
  PLACEHOLDER_MAPPING = { # For filling in fields
    aces: "1", twos: "2", threes: "3", fours: "4", fives: "5", sixes: "6",
    three_of_a_kind: "k", four_of_a_kind: "K", full_house: "h",
    small_straight: "s", large_straight: "S", yahtzee: "y", chance: "c",
    upper_bonus: "b", upper_total: "t", lower_total: "T", yahtzee_bonus: "B-",
    grand_total: "g-"
  }.freeze
  GRID_COMBO_NAMES = [ # For navigating the sheet
    %i[aces three_of_a_kind],
    %i[twos four_of_a_kind],
    %i[threes full_house],
    %i[fours small_straight],
    %i[fives large_straight],
    %i[sixes yahtzee],
    [nil, :chance]
  ].freeze
  LABEL_MAPPING = { # For highlighting selected sections
    aces: "ACES              ",
    twos: "TWOS              ",
    threes: "THREES            ",
    fours: "FOURS             ",
    fives: "FIVES             ",
    sixes: "SIXES             ",
    three_of_a_kind: "3 OF A KIND ",
    four_of_a_kind: "4 OF A KIND ",
    full_house: "FULL HOUSE  ",
    small_straight: "SMALL STR8  ",
    large_straight: "LARGE STR8  ",
    yahtzee: "YAHTZEE     ",
    chance: "CHANCE      "
  }.freeze
  STARTING_SCORES = { # For initializing scores
    1 => {
      aces: nil, twos: nil, threes: nil, fours: nil, fives: nil, sixes: nil,
      three_of_a_kind: nil, four_of_a_kind: nil, full_house: nil,
      small_straight: nil, large_straight: nil, yahtzee: nil, chance: nil,
      upper_bonus: nil, yahtzee_bonus: nil,
      upper_total: nil, lower_total: nil, grand_total: nil
    },
    2 => {
      aces: nil, twos: nil, threes: nil, fours: nil, fives: nil, sixes: nil,
      three_of_a_kind: nil, four_of_a_kind: nil, full_house: nil,
      small_straight: nil, large_straight: nil, yahtzee: nil, chance: nil,
      upper_bonus: nil, yahtzee_bonus: nil,
      upper_total: nil, lower_total: nil, grand_total: nil
    }
  }.freeze

  attr_accessor :showing_possible_scores
  attr_reader :current_player, :starting_player

  # @param [Yahtzee]
  def initialize(yahtzee)
    @yahtzee = yahtzee
    @dice = yahtzee.dice # @type [DiceSet]

    @scores = STARTING_SCORES.dup
    @starting_player = 1
    @current_player = @starting_player
    @showing_possible_scores = false

    @selected_section_pos = [0, 0]
  end

  def sheet_template
    <<~SHEET
                           ╭─────┬─────╮                ╭─────┬─────╮
      UPPER SECTION        │ P.1 │ P.2 │ LOWER SECTION  │ P.1 │ P.2 │
      ╭────────────────────┼─────┼─────┤ ╭──────────────┼─────┼─────┤
      │ ACES               │ %11 │ %21 │ │ 3 OF A KIND  │ %1k │ %2k │
      ├────────────────────┼─────┼─────┤ ├──────────────┼─────┼─────┤
      │ TWOS               │ %12 │ %22 │ │ 4 OF A KIND  │ %1K │ %2K │
      ├────────────────────┼─────┼─────┤ ├──────────────┼─────┼─────┤
      │ THREES             │ %13 │ %23 │ │ FULL HOUSE   │ %1h │ %2h │
      ├────────────────────┼─────┼─────┤ ├──────────────┼─────┼─────┤
      │ FOURS              │ %14 │ %24 │ │ SMALL STR8   │ %1s │ %2s │
      ├────────────────────┼─────┼─────┤ ├──────────────┼─────┼─────┤
      │ FIVES              │ %15 │ %25 │ │ LARGE STR8   │ %1S │ %2S │
      ├────────────────────┼─────┼─────┤ ├──────────────┼─────┼─────┤
      │ SIXES              │ %16 │ %26 │ │ YAHTZEE      │ %1y │ %2y │
      ├────────────────────┼─────┼─────┤ ├──────────────┼─────┼─────┤
      │ BONUS (if sum ≥63) │ %1b │ %2b │ │ CHANCE       │ %1c │ %2c │
      ├────────────────────┼─────┼─────┤ ├──────────────┼─────┼─────┤
      │ TOTAL              │ %1t │ %2t │ │ TOTAL        │ %1T │ %2T │
      ╰────────────────────┴─────┴─────╯ ╰──────────────┴─────┴─────╯
      ╭───────────────────────────────────────────────┬──────┬──────╮
      │ YAHTZEE BONUSES (+100 EACH)                   │ %1B- │ %2B- │
      ├───────────────────────────────────────────────┼──────┼──────┤
      │ GRAND TOTAL                                   │ %1g- │ %2g- │
      ╰───────────────────────────────────────────────┴──────┴──────╯
    SHEET
  end

  def move_selection(direction)
    dx, dy = case direction
             when :up then [0, -1]
             when :down then [0, 1]
             when :left then [-1, 0]
             when :right then [1, 0]
             else
               raise ArgumentError,
                     "Invalid direction: #{direction.inspect}"
             end

    loop do
      self.selected_x = (selected_x + dx) % cols
      self.selected_y = (selected_y + dy) % rows

      break if selected_field && current_player_score(selected_field).nil?
    end
  end

  # Get score for current player.
  # @param field [Symbol]
  # @return [Integer]
  def current_player_score(field)
    unless VALID_FIELDS.include? field
      raise ArgumentError, "Invalid field: #{field.inspect}"
    end
    @scores[@current_player][field]
  end

  def set_current_player_score(field, value)
    unless VALID_FIELDS.include? field
      raise ArgumentError, "Invalid field: #{field.inspect}"
    end
    unless value.is_a? Integer
      raise ArgumentError, "Expected Integer for value, got #{value.class}"
    end
    @scores[@current_player][field] = value
  end

  # Should be called when the user presses Enter.
  # Rejects combos already filled and adds a message to the +Yahtzee.messages+
  # array saying so (this shouldn't happen though, since the navigation system
  # should skip filled fields, but just in case).
  def enter_combo
    score_earned = @dice.score_for_combo(selected_field)
    @yahtzee.add_message(
      "Player #{@current_player} played #{selected_field.to_s.upcase.bold} " \
      "for #{score_earned.to_s.bold} points."
    )
    update_score(selected_field, score_earned)

    @yahtzee.add_message "Use arrow keys to select a field and Enter."

    @yahtzee.finish_game if all_fields_filled?(1) && all_fields_filled?(2)
  end

  def next_player
    @current_player = @current_player == 1 ? 2 : 1
    @dice.reset

    @yahtzee.add_message(
      "Player #{@current_player}'s".color(current_player_color) + " turn!"
    )
    select_closest_unfilled_field
  end

  def select_closest_unfilled_field
    neighbors = [
      [(selected_y + 1) % rows, selected_x],
      [(selected_y - 1) % rows, selected_x],
      [selected_y, (selected_x + 1) % cols]
    ]

    all_coords = (0...rows).to_a.product((0...cols).to_a)

    found = (neighbors + all_coords).find do |y, x|
      combo = GRID_COMBO_NAMES[y][x]
      combo && current_player_score(combo).nil?
    end

    self.selected_y, self.selected_x = found if found
  end

  # Update a field in +@scores+ with a value for the current player.
  # @param field [Symbol]
  # @param value [Integer]
  def update_score(field, value)
    unless VALID_FIELDS.include? field
      raise ArgumentError, "Invalid field: #{field.inspect}"
    end

    set_current_player_score(field, value)
  end

  # Fill a field in the +sheet_template+ with a value and return the resulting
  # string.
  # @param player_num [Integer]
  # @param field [Symbol]
  # @param value [Integer]
  # @return [String]
  def fill_field(sheet_template, player_num, field, value)
    sym = PLACEHOLDER_MAPPING[field]
    placeholder = "%#{player_num}#{sym}"
    sheet_template.gsub(placeholder,
                        value.to_s.rjust(sym[-1] == "-" ? 4 : 3)
                              .bold.color(player_num == 1 ? :red : :blue))
  end

  # Same as +fill_field+, but uses dim text.
  # Will not replace actual filled scores.
  # @param sheet_template [String] sheet template.
  # @param player_num [Integer]
  # @param field [Symbol]
  # @param value [Integer]
  # @return [String]
  def fill_possible(sheet_template, player_num, field, value)
    unless VALID_FIELDS.include? field
      raise ArgumentError, "Invalid field: #{field.inspect}"
    end

    sym = PLACEHOLDER_MAPPING[field]
    placeholder = "%#{player_num}#{sym}"

    if selected_field == field
      sheet_template.gsub(
        placeholder, value.to_s.rjust(sym[-1] == "-" ? 4 : 3)
                          .bold.white.bg(current_player_color)
      )
    else
      sheet_template.gsub(
        placeholder, value.to_s.rjust(sym[-1] == "-" ? 4 : 3).faint
      )
    end
  end

  # A string of the scoresheet with all possible scores filled in for the
  # current player.
  # @return [String]
  def fill_possible_scores(temp_sheet)
    if @yahtzee.turn_started?
      bonuses = { upper_bonus: upper_bonus, yahtzee_bonus: yahtzee_bonus }
      @dice.combos.merge(bonuses).each_pair do |key, value|
        temp_sheet = fill_possible(temp_sheet, @current_player, key, value)
      end
    end
    highlight_selection(temp_sheet).gsub(/%[1-2][a-zA-Z0-9]-/, "    ")
                                   .gsub(/%[1-2][a-zA-Z0-9]/, "   ")
  end

  # Should only be called in +fill_possible+, since the user should only be
  # able to select unfilled fields.
  # Highlights the currently selected field in the scoresheet.
  # @return [String]
  def highlight_selection(sheet)
    return sheet unless selected_field

    label = LABEL_MAPPING[selected_field]

    sheet.sub(label, label.bold.white.bg(current_player_color))
  end

  # Sheet as a string, but no possible scores filled in.
  # That is done in +possible_scores+.
  # Set +remove_remaining_placeholders+ to false when using in #possible_scores
  # @return [String]
  def to_s
    temp_sheet = sheet_template

    @scores.each_pair do |player, scores|
      scores.each_pair do |key, value|
        next if value.nil?
        temp_sheet = fill_field(temp_sheet, player, key, value)
      end
    end
    temp_sheet = if @yahtzee.turn_started?
                   fill_possible_scores(temp_sheet)
                 else
                   temp_sheet.gsub(/%[1-2][a-zA-Z0-9]-/, "    ")
                             .gsub(/%[1-2][a-zA-Z0-9]/, "   ")
                 end
    temp_sheet = highlight_selection(temp_sheet) if @yahtzee.turn_started?
    temp_sheet.gsub("P.1", "\e[1m\e[31mP.1\e[0m")
              .gsub("P.2", "\e[1m\e[34mP.2\e[0m")
  end

  # ========================================================================
  # ========================================================================

  # @return [Integer]
  def rows
    GRID_COMBO_NAMES.size
  end

  # @return [Integer]
  def cols
    GRID_COMBO_NAMES.first.size
  end

  # @return [Symbol]
  def selected_field
    GRID_COMBO_NAMES[selected_y][selected_x]
  end

  # @return [Integer]
  def selected_x
    @selected_section_pos.first
  end

  # @return [Integer]
  def selected_y
    @selected_section_pos.last
  end

  # @param val [Integer]
  def selected_x=(val)
    unless (0..1).cover? val
      raise ArgumentError, "Selected x cannot be #{val.inspect}"
    end
    @selected_section_pos[0] = val
  end

  # @param val [Integer]
  def selected_y=(val)
    unless (0..6).cover? val
      raise ArgumentError, "Selected y cannot be #{val.inspect}"
    end
    @selected_section_pos[1] = val
  end

  # @return [Integer]
  def upper_bonus
    if @scores[@current_player].values_at(*UPPER_FIELDS).compact.sum >= 63
      35
    else
      0
    end
  end

  # Returns 100 more than the current score unless the current player has not
  # scored a Yahtzee yet, in which case it returns 0.
  # @return [Integer]
  def yahtzee_bonus
    if (current_player_score(:yahtzee) || 0) >= 50 &&
       @dice.combos[:yahtzee] == 50
      current_player_score(:yahtzee) + 100
    else
      0
    end
  end

  # Player num defaults to current player.
  # @param player_num [Integer]
  # @return [Boolean]
  def upper_section_filled?(player_num = @current_player)
    !@scores[player_num].values_at(*UPPER_FIELDS).include?(nil)
  end

  # Player num defaults to current player.
  # @param player_num [Integer]
  # @return [Boolean]
  def lower_section_filled?(player_num = @current_player)
    !@scores[player_num].values_at(*LOWER_FIELDS).include?(nil)
  end

  # Player num defaults to current player.
  # @param player_num [Integer]
  # @return [Boolean]
  def all_fields_filled?(player_num = @current_player)
    upper_section_filled?(player_num) && lower_section_filled?(player_num)
  end

  # +:red+ or +:blue+
  # @return [Symbol]
  def current_player_color
    @current_player == 1 ? :red : :blue
  end

  # Restores sheet to initial state.
  def reset
    @scores = STARTING_SCORES.dup
    @starting_player = 1
    @current_player = @starting_player
    @showing_possible_scores = false

    @selected_section_pos = [0, 0]
  end
end

# frozen_string_literal: true

require "rainbow/refinement"

using Rainbow

class Die
  include Comparable

  attr_reader :num

  # @param [Yahtzee]
  def initialize(yahtzee)
    @yahtzee = yahtzee
    @keep = false
    @num = nil
  end

  # @return [String]
  def to_s
    out = case @num
          when 1 then <<~ONE
            ╭────────╮
            │        │
            │   ⬤    │
            │        │
            ╰────────╯
          ONE
          when 2 then <<~TWO
            ╭────────╮
            │ ⬤      │
            │        │
            │     ⬤  │
            ╰────────╯
          TWO
          when 3 then <<~THREE
            ╭────────╮
            │ ⬤      │
            │   ⬤    │
            │     ⬤  │
            ╰────────╯
          THREE
          when 4 then <<~FOUR
            ╭────────╮
            │ ⬤   ⬤  │
            │        │
            │ ⬤   ⬤  │
            ╰────────╯
          FOUR
          when 5 then <<~FIVE
            ╭────────╮
            │ ⬤   ⬤  │
            │   ⬤    │
            │ ⬤   ⬤  │
            ╰────────╯
          FIVE
          when 6 then <<~SIX
            ╭────────╮
            │ ⬤   ⬤  │
            │ ⬤   ⬤  │
            │ ⬤   ⬤  │
            ╰────────╯
          SIX
          else <<~NIL
            ╭────────╮
            │        │
            │   ⭐️   │
            │        │
            ╰────────╯
          NIL
          end
    return out.lines.map { |line| line.chomp.green }.join("\n") if kept?
    out
  end

  # Roles this die, unless it has been kept.
  def roll
    @num = rand 1..6 unless kept?
  end

  def toggle_keep
    kept? ? unkeep : keep
  end

  def keep
    @keep = true if @yahtzee.started?
  end

  def unkeep
    @keep = false
  end

  def reset
    unkeep
    @num = nil
  end

  # @return [Boolean]
  def kept?
    @keep
  end

  # @param other [Die]
  # @return [Integer, nil]
  def <=>(other)
    other.is_a?(Die) ? @num <=> other.num : nil
  end
end

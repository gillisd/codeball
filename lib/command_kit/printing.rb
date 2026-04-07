module CommandKit
  # Extends +CommandKit::Printing+ with color-aware table printing.
  #
  # Computes column widths from raw text, then applies ANSI color
  # after padding so escape sequences don't break alignment.
  module Printing
    def print_table_color(rows, header: nil, color: :green, index: 0, **)
      all_rows = header ? [header] + rows : rows
      widths = column_widths(all_rows)
      print_header(header, widths) if header
      rows.each do |row|
        line = format_row(row, widths, color, index)
        puts line.join("  ")
      end
    end

    private

    def print_header(header, widths)
      line = header.each_with_index.map do |cell, i|
        colors.bold(cell.to_s.ljust(widths[i]))
      end
      puts line.join("  ")
    end

    def format_row(row, widths, color, index)
      row.each_with_index.map do |cell, i|
        padded = cell.to_s.ljust(widths[i])
        i == index ? colors.public_send(color, padded) : padded
      end
    end

    def column_widths(rows)
      rows.each_with_object(Hash.new(0)) do |row, widths|
        row.each_with_index do |cell, i|
          len = cell.to_s.length
          widths[i] = len if len > widths[i]
        end
      end
    end
  end
end

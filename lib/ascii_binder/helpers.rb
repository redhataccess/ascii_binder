module AsciiBinder
  module Helpers
    BLANK_STRING_RE = Regexp.new('^\s*$')
    ID_STRING_RE    = Regexp.new('^[A-Za-z0-9\-\_]+$')

    def valid_id?(check_id)
      return false unless check_id.is_a?(String)
      return false unless check_id.match ID_STRING_RE
      return true
    end

    def valid_string?(check_string)
      return false unless check_string.is_a?(String)
      return false unless check_string.length > 0
      return false if check_string.match BLANK_STRING_RE
      return true
    end
  end
end

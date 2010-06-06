class LogUser < Sequel::Model
  many_to_one :log
end

require 'config/init.rb'

DB = Sequel.connect(
  :adapter => DataBase::Config['development']['adapter'],
  :host => DataBase::Config['development']['host'],
  :database => DataBase::Config['development']['database'],
  :user => DataBase::Config['development']['user'],
  :password => DataBase::Config['development']['password']
)
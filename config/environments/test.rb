require 'config/init'

DB = Sequel.connect(
  :adapter => DataBase::Config['test']['adapter'],
  :host => DataBase::Config['test']['host'],
  :database => DataBase::Config['test']['database'],
  :user => DataBase::Config['test']['user'],
  :password => DataBase::Config['test']['password']
)

drop_tables
create_tables

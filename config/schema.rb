def create_tables
  DB.create_table :users do
    primary_key :id
    column :nick, :varchar
    column :name, :varchar
    column :location, :varchar
    column :page_rank, :float
  end

  create_communities_tables

  DB.create_table :twitts do
    primary_key :id, :varchar, :auto_increment => false
    foreign_key :parent_id, :twitts, :type => :varchar
    column :date, :timestamp
    column :body, :text
    foreign_key :user_id, :users
  end

  DB.create_table :user_followers do
    primary_key :id
    foreign_key :user_id, :users
    foreign_key :follower_id, :users
  end

  DB.create_table :sequence_parts do
    primary_key :id
    foreign_key :start_edge_id, :users
    foreign_key :end_edge_id, :users
    column :vector_number, :integer
    column :position, :integer
  end

  DB.create_table :sequence_freqs do
    primary_key :key, :varchar, :auto_increment => false
    column :frequency, :integer
    column :length, :integer
  end
end

def create_communities_tables
  DB.create_table :communities do
    primary_key :id
    foreign_key :parent_id, :communities
    column :strength, :float
    column :density, :float
  end

  DB.create_table :communities_users do
    primary_key :id
    foreign_key :user_id, :users
    foreign_key :community_id, :communities
  end
end

def drop_communities_tables
  DB.drop_table :communities
  DB.drop_table :communities_users
end

def drop_tables
  drop_communities_tables
  DB.drop_table :sequence_parts
  DB.drop_table :sequence_freqs
  DB.drop_table :user_followers
  DB.drop_table :twitts
  DB.drop_table :users
end

def clear_communities_tables
  drop_communities_tables
  create_communities_tables
end

def clear_tables
  drop_tables
  create_tables
end
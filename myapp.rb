require 'sinatra'
require 'sinatra/reloader'
require 'sqlite3'
require 'bcrypt'

# set up database connection
db = SQLite3::Database.new "myapp.db"
db.execute "CREATE TABLE IF NOT EXISTS users(id INTEGER PRIMARY KEY AUTOINCREMENT, username TEXT, password TEXT, total_wins INT, total_losses INT,overall_win INT,overall_loss INT,profit INT,total_profit INT)"
db.results_as_hash = true
configure do
    set :db, db
  end

# enable sessions
enable :sessions

# helper method to check if user is logged in
def logged_in?
  session[:user_id] != nil
end

# helper method to retrieve user's total wins and losses from the database
def get_user_totals(db, user_id)
    #result = settings.db.execute("SELECT total_wins, total_losses, overall_win,profit,total_profit overall_loss FROM users WHERE id=?", [user_id]).first
    #return { wins: result['total_wins'], losses: result['total_losses'], twin: result['overall_win'] , tloss: result['overall_loss'] , profit: result['profit'] , tprofit: result['total_profit'] }
    # retrieve user's total wins and losses from the database
  row = db.get_first_row("SELECT total_wins, total_losses, overall_win, overall_loss, profit, total_profit FROM users WHERE id = ?", user_id)
  # initialize totals hash with default values
  totals = { wins: 0, losses: 0, twin: 0, tloss: 0, profit: 0, tprofit: 0 }
  # update totals hash with values from database
  totals[:wins] = row[0] unless row[0].nil?
  totals[:losses] = row[1] unless row[1].nil?
  totals[:twin] = row[2] unless row[2].nil?
  totals[:tloss] = row[3] unless row[3].nil?
  totals[:profit] = row[4] unless row[4].nil?
  totals[:tprofit] = row[5] unless row[5].nil?
  return totals
end

# login page
get '/' do
  erb :login
end

# process login form
post '/login' do
  # retrieve user from database
  result = db.execute("SELECT * FROM users WHERE username=?", [params[:username]]).first
  
  # check if password is correct
  if result && BCrypt::Password.new(result['password']) == params[:password]
    # store user ID in session and redirect to betting page
    session[:user_id] = result['id']
    # set user's total wins and losses to 0
    settings.db.execute("UPDATE users SET total_wins=?, total_losses=?, profit=? WHERE id=?", [0, 0,0, session[:user_id]])
    redirect '/bet'
  else
    # display error message and redirect back to login page
    @error = "Invalid username or password"
    erb :registeration
  end
end

# process registration form
post '/register' do
  # retrieve user from database
  result = settings.db.execute("SELECT * FROM users WHERE username=?", [params[:username]]).first
  
  # check if username already exists
  if result
    # display error message and redirect back to registration page
    @error = "Username already taken"
    erb :register
  else
    # hash password and insert user into database
    password_hash = BCrypt::Password.create(params[:password])
    db.execute("INSERT INTO users (username, password, total_wins, total_losses, overall_win, overall_loss, profit, total_profit) VALUES (?, ?, 0, 0, 0, 0, 0, 0)", [params[:username], password_hash])
    
    # redirect to login page
    redirect '/'
  end
end

# registration page
get '/register' do
  erb :register
end

# betting page
get '/bet' do
  # check if user is logged in
  redirect '/' unless logged_in?
  
 # retrieve user's total wins and losses from the database
 totals = get_user_totals(settings.db, session[:user_id])
  
  erb :bet, locals: { totals: totals,db: settings.db}
  #puts "params: #{params.inspect}"
end

# process bet form
post '/bet' do
    puts "params: #{params.inspect}"
  # check if user is logged in
  redirect '/' unless logged_in?
  
 # retrieve user's total wins and losses from the database
 totals = get_user_totals(settings.db, session[:user_id])

  bet = params[:bet].to_i
  amount = params[:amount].to_i
  dice_roll = rand(1..6)
  puts "Dice roll: #{dice_roll}"
  puts "bet: #{bet}"
  puts "params: #{params.inspect}"
  # calculate result of bet
  if dice_roll==bet
    # user wins
    result_text = "You win!"
    totals[:wins] += 1
    totals[:twin] += 1
    if amount.nil?
        # handle error here
      else
        totals[:profit] += amount
        totals[:tprofit] += amount
      end
      
  else
    # user loses
    result_text = "You lose!"
    totals[:losses] += 1
    totals[:tloss] += 1
    if amount.nil?
        # handle error here
      else
        totals[:profit] -= amount
        totals[:tprofit] -= amount
      end
      
  end
  
  # update session with new totals
  session[:totals] = totals
  # update database with new totals
  settings.db.execute("UPDATE users SET total_wins=?, total_losses=? ,overall_win=? ,overall_loss=?,profit=?,total_profit=? WHERE id=?", [totals[:wins], totals[:losses],totals[:twin], totals[:tloss], totals[:profit], totals[:tprofit], session[:user_id]])
  
  erb :bet, locals: { result_text: result_text, totals: totals }
end
  

# process logout action
post '/logout' do
  # check if user is logged in
  redirect '/' unless logged_in?

  # retrieve user's total wins and losses from the database
  totals = get_user_totals(session[:user_id])

  # update database with session totals
  #db.execute("UPDATE users SET total_wins=total_wins+?, total_losses=total_losses+? WHERE id=?", [totals[:wins], totals[:losses], session[:user_id]])

  # clear session and redirect to login page
  session.clear
  redirect '/'
end
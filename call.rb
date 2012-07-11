##
## Author: D:evolute
## proudly presented by adap:to
## devolute.org

require 'net/http'

ENV['TZ'] = 'IST'


## configuration for the Ushahidi Crowdmap
USHAHIDI_CONFIG = {
  :url => 'meraswasthyameriaawaz.org/api',
  :parameters => {
    :required => { },
    :optional => {
      :task => 'task',
      :by => 'by',
      :action => 'action',
      :incident_id => 'incident_id'
    },
  },
  :authentication => {
    :basic_auth => {
      :user => 'admin',
      :password => 'admin' },
  },
}


## class to set up the gateway (Net::HTTP), method (POST) and user credentials for sending data to Ushahidi/Crowdmap
class UshahidiGateway

  attr_reader :user, :password

  def initialize(credentials)
    @user = credentials[:user]
    @password = credentials[:password]
  end

  def get url
     raise "implement get method for the Ushahidi gateway"
  end

  def post url, payload
    response = Net::HTTP.post_form(URI.parse("http://#{user}:#{password}@" + url), payload )
    response.body
  end

end

## class to set up the incident data (payload) for sending it to Crowdmap
class UshahidiClient

  attr_reader :config, :gateway, :url

  def initialize
    @config = USHAHIDI_CONFIG
    @gateway = UshahidiGateway.new( config[:authentication][:basic_auth] )
    @url = config[:url]
  end


  def post_report report
    gateway.post( url, build_options_from(report) )
  end

  private

  def build_options_from report
    payload = {
      :task => 'report',
      :incident_title => report[:title],
      :incident_description => report[:description],
      :incident_category => report[:category],
      :incident_date => get_date_and_time[:date],
      :incident_hour => get_date_and_time[:hours],
      :incident_minute => get_date_and_time[:minutes],
      :incident_ampm => get_date_and_time[:am_pm],
      :latitude => report[:latitude],
      :longitude => report[:longitude],
      :location_name => report[:location_name]
    }
    # log is a function from the tropo framework, it puts up text in the log file
    log("payload: #{payload}")
    payload
  end

  def get_date_and_time
    t = Time.new
    time_hash = { }
    time_hash[:am_pm]= t.strftime("%P")
    time_hash[:hours]= t.strftime("%I")
    time_hash[:minutes]= t.strftime("%M")
    time_hash[:date]= t.strftime("%m/%d/%Y")
    time_hash
  end

end



## module is for local testing only
module LocalTesting

  class CurrentCall

    def callerID
      "foo"
    end

    def network
      "vodafone"
    end

    def callerName
      "CallerName"
    end

    def isActive
      true
    end

  end
  
  ## next line is for local testing only
  #$currentCall = CurrentCall.new

  class Event

    def initialize(value)
      @value = value
    end

    def name
      "choice"
    end

    def value
      @value
    end

  end

  def answer
    puts "answer"
  end

  def ask(what, options)
    puts "asked #{what} - #{options}"

    @ask_count ||= 0
    @ask_count += 1
    puts "ask count: #{@ask_count}"
    dialing = ['8','0023','1','1','1','1','1','3','1','1',
               '1','3',   '1','1','1','2','1','1','1','3',
               '1','1',   '1','3','1','1','1','3','1','1',
               '1','3',   '1','1','1']
    if dialing[@ask_count]
      value = dialing[@ask_count]
    else
      value = '5'
    end

    puts "value is #{value}"

    event = Event.new(value)

    if options[:choices]
      if options[:choices].match("DIGIT")
        choices = ['0023']
      else
        choices = options[:choices].split(',')
      end
    end

    if choices
      if choices.include?(value)
        options[:onChoice].call(event) if options[:onChoice]
      else
        options[:onBadChoice].call(event) if options[:onBadChoice]
      end
    end
    event
  end

  def say(what, options={})
    puts "say #{what}"
  end

  def call(where)
    puts "calls #{where}"
  end

  def redirect(where)
    puts "redirects #{where}"
  end

  def transfer(where)
    puts "transfers #{where}"
  end

  def log(what)
    puts "logged: #{what}}"
  end

  def hangup
    puts "hung up"
    exit
  end

  def wait(howlong)
    "waiting #{howlong}"
  end
end


## main class
class Call

  ## next line is for local testing only
  #include LocalTesting


  attr_accessor :caller_info

  # constant for enabling debugging messages in the tropo log file
  DEBUG = true

  # !!! MAINTENANCE MODE LEVER !!!
  # if turned on, the hotline only plays the MAINTENANCE_MESSAGE, you have to dial '8' to get through
  MAINTENANCE_MODE = false
  MAINTENANCE_PASSWORD = '8'
  MAINTENANCE_MESSAGE = ["The help line is currently undergoing maintenance. Please call again later.", {"voice" => "kate"}]

  # URL of the used audio files (hosted at the tropo account)
  AUDIO_URL = "http://hosting.tropo.com/104666/www/sayahog/audio/"
  AUDIO_TYPE = ".gsm"


  # incident code -> description
  INCIDENTS = {
  'a' => 'a: emergency',
  'b' => 'b: been asked to pay for medicines, examination, gloves, soap, etc.', 
  'c' => 'c: been asked to pay for blood or operation',
  'd' => 'd: been sent to another hospital with a referral slip or an ambulance', 
  'e' => 'e: been given free food and vehicle in the hospital covered under janani surakhsha scheme', 
  'f' => 'f: been asked to pay during delivery or when you asked for the cheque of 1400 given under janani suraksha scheme', 
  }

#  INCIDENTS = {
#    '1' => 'Health worker asked for bribe to admit the patient or treat the patient in hospital.',
#    '2' => 'The patient was asked to pay money after delivery.',
#    '3' => 'The patient was asked to pay for drugs, blood, tests, etc.',
#    '4' => 'The patient was asked to purchase drugs, gloves, soap etc from outside.',
#    '5' => 'The staff asked the patient to go to another hospital without a referral slip.',
#    '6' => 'The patient was asked a bribe for payments of JSY.',
#    '7' => 'The patient had to pay for the vehicle that brought them to hospital.',
#    '8' => 'The patient was asked to pay for or not provided with food during their stay in the JSSK hospitals.',
#    '9' => 'The patient were not provided with free drop back facility from JSSK hospitals.',
#    '0' => 'This is a situation which might result in death of the woman/child and no action is being taken by the staff.',
#  }

  MONEY_CODES = {'2' => 'More_than_500', '1' => 'Less_than_500'}

  MONEY_DESCRIPTION ={'2' => 'It was about more then 500 Rupees', '1' => 'It was about less then 500 Rupees'}

  # secret decoder ring for health facilities
  # site number (key): site, location, phone
  # these sites are in the Azamgar District
  SITES = {
    '0001' => {'name'=>'Azamgarh Sadar Mahila Hospital', 'location'=>'26.063777,83.183628', 'phone'=>'+919473826492', 'district' => 'Azamgarh_Zila_District'},
    '0002' => {'name'=>'Phoolpur', 'location'=>'26.044017,82.520839', 'phone'=>'+919473826492', 'district' => 'Azamgarh_Zila_District'},
    '0003' => {'name'=>'Lalganj', 'location'=>'25.450143,82.59002', 'phone'=>'+919473826492', 'district' => 'Azamgarh_Zila_District'},
    '0004' => {'name'=>'Atraulia', 'location'=>'26.10495,82.541362', 'phone'=>'+919473826492', 'district' => 'Azamgarh_Zila_District'},
    '0005' => {'name'=>'Koilsa', 'location'=>'26.181165,82.581841', 'phone'=>'+919473826492', 'district' => 'Azamgarh_Zila_District'},
    '0006' => {'name'=>'Pawayi', 'location'=>'26.155774,83.011249', 'phone'=>'+919473826492', 'district' => 'Azamgarh_Zila_District'},
    '0007' => {'name'=>'Mehnagr', 'location'=>'25.525119,83.065119', 'phone'=>'+919473826492', 'district' => 'Azamgarh_Zila_District'},
    '0008' => {'name'=>'Haraiya', 'location'=>'26.645412,83.928797', 'phone'=>'+919473826492', 'district' => 'Azamgarh_Zila_District'},
    '0009' => {'name'=>'Ahiraula', 'location'=>'26.104961,82.541324', 'phone'=>'+919473826492', 'district' => 'Azamgarh_Zila_District'},
    '0010' => {'name'=>'Martinganj', 'location'=>'25.570156,82.47313', 'phone'=>'+919473826492', 'district' => 'Azamgarh_Zila_District'},
    '0011' => {'name'=>'Palhni', 'location'=>'26.021551,83.09345', 'phone'=>'+919473826492', 'district' => 'Azamgarh_Zila_District'},
    '0012' => {'name'=>'Rani ki Sarai', 'location'=>'26.000459,83.062549', 'phone'=>'+919473826492', 'district' => 'Azamgarh_Zila_District'},
    '0013' => {'name'=>'Mohammdpur', 'location'=>'25.575318,83.014912', 'phone'=>'+919473826492', 'district' => 'Azamgarh_Zila_District'},
    '0014' => {'name'=>'Mirzapur', 'location'=>'26.035728,82.565781', 'phone'=>'+919473826492', 'district' => 'Azamgarh_Zila_District'},
    '0015' => {'name'=>'Tahbarpur', 'location'=>'26.095543,83.060374', 'phone'=>'+919473826492', 'district' => 'Azamgarh_Zila_District'},
    '0016' => {'name'=>'Jahanaganj', 'location'=>'25.494027,83.13071', 'phone'=>'+919473826492', 'district' => 'Azamgarh_Zila_District'},
    '0017' => {'name'=>'Sathiyav', 'location'=>'26.075659,82.53107', 'phone'=>'+919473826492', 'district' => 'Azamgarh_Zila_District'},
    '0018' => {'name'=>'Thekma', 'location'=>'25.530044,82.565966', 'phone'=>'+919473826492', 'district' => 'Azamgarh_Zila_District'},
    '0019' => {'name'=>'Tarwa', 'location'=>'25.450617,83.111857', 'phone'=>'+919473826492', 'district' => 'Azamgarh_Zila_District'},
    '0020' => {'name'=>'Ajmatgarh', 'location'=>'26.166292,83.36433', 'phone'=>'+919473826492', 'district' => 'Azamgarh_Zila_District'},
    '0021' => {'name'=>'Bilariyaganj', 'location'=>'26.120036,83.134831', 'phone'=>'+919473826492', 'district' => 'Azamgarh_Zila_District'},
    '0022' => {'name'=>'Maharajganj', 'location'=>'26.152813,83.064907', 'phone'=>'+919473826492', 'district' => 'Azamgarh_Zila_District'},
    # everything below here is in the Mirzapur District
    '0023' => {'name'=>'Mirzapur District Women\'s Hospital', 'location'=>'25.154094,82.577234', 'phone'=>'+919450074037', 'district' => 'Mirazpur_Zila_District'},
    '0024' => {'name'=>'Chunar', 'location'=>'25.061756,82.520419', 'phone'=>'+919450074037', 'district' => 'Mirazpur_Zila_District'},
    '0025' => {'name'=>'Madihan', 'location'=>'24.550976,82.403875', 'phone'=>'+919450074037', 'district' => 'Mirazpur_Zila_District'},
    '0026' => {'name'=>'Lalganj', 'location'=>'24.594401,82.202413', 'phone'=>'+919450074037', 'district' => 'Mirazpur_Zila_District'},
    '0027' => {'name'=>'Majavah', 'location'=>'25.266431,82.709198', 'phone'=>'+919450074037', 'district' => 'Mirazpur_Zila_District'},
    '0028' => {'name'=>'Rajgarh', 'location'=>'24.525589,82.52173', 'phone'=>'+919450074037', 'district' => 'Mirazpur_Zila_District'},
    '0029' => {'name'=>'Haliya', 'location'=>'24.491444,82.185563', 'phone'=>'+919450074037', 'district' => 'Mirazpur_Zila_District'},
    '0030' => {'name'=>'Vijaypur', 'location'=>'25.073399,82.378023', 'phone'=>'+919450074037', 'district' => 'Mirazpur_Zila_District'},
    '0031' => {'name'=>'Jamalpur', 'location'=>'25.09245,83.052788', 'phone'=>'+919450074037', 'district' => 'Mirazpur_Zila_District'},
    '0032' => {'name'=>'Chil', 'location'=>'25.152229,82.563699', 'phone'=>'+919450074037', 'district' => 'Mirazpur_Zila_District'},
    '0033' => {'name'=>'Kon', 'location'=>'25.214376,82.583189', 'phone'=>'+919450074037', 'district' => 'Mirazpur_Zila_District'},
    '0034' => {'name'=>'Pahadi', 'location'=>'25.050047,82.450017', 'phone'=>'+919450074037', 'district' => 'Mirazpur_Zila_District'},
    '0035' => {'name'=>'Nagar (Gurusandi)', 'location'=>'25.160245,82.589738', 'phone'=>'+919450074037', 'district' => 'Mirazpur_Zila_District'},
    '0036' => {'name'=>'Patehra', 'location'=>'24.553075,82.353919', 'phone'=>'+919450074037', 'district' => 'Mirazpur_Zila_District'},
    '0037' => {'name'=>'Ahiraura', 'location'=>'25.038327,82.998962', 'phone'=>'+919450074037', 'district' => 'Mirazpur_Zila_District'},
    '0038' => {'name'=>'Sikhar', 'location'=>'25.074132,82.485834', 'phone'=>'+919450074037', 'district' => 'Mirazpur_Zila_District'},
    '0039' => {'name'=>'Vindhyachal', 'location'=>'25.095163,82.302222', 'phone'=>'+919450074037', 'district' => 'Mirazpur_Zila_District'},
    '0040' => {'name'=>'Narayanpur', 'location'=>'25.204941,83.020935', 'phone'=>'+919450074037', 'district' => 'Mirazpur_Zila_District'}
  }
  # end decoder ring

 
  def initialize
    @maintainance_authorized = false
    @caller_info = {}
    @retries = {}
    @ask_default_options = {
      :mode => 'dtmf',
      :bargein => true,
      :attempts => 3
    }
  end


  ## method for running all the main functions in the designed order
  def run
    
    # accept the incomming call
    answer()

    # hangup if maintenance mode is active but not authorized
    authorize_maintainance_mode if MAINTENANCE_MODE

    # store basic caller information (name, number, set retries to 0)
    store_initial_caller_info if $currentCall.isActive
    # $currentCall is a global variable which is passed through from the tropo application
    # and contains all information about the current incomming call

    ## plays the "welcome" message
    # TODO say(isay("0_1_Welcome_Message")) if $currentCall.isActive

    # TODO wait(100) if $currentCall.isActive

    # retries getting the site till successful, or kicks out the user after too many retries
    # after it ran successfully we have a @site instance variable with the chosen site
    get_site_info if $currentCall.isActive

    
     
    
    
   # gets current incident code
   # stores the incident action, or kicks out after several retries
   get_incident_code_and_type! if $currentCall.isActive

#    # either asks for the amount of money
#    # or in emergency sends report to call the number
#    incident_action! if $currentCall.isActive
   byenow!
   
   
   # report = build_report caller_info
  end

  
  
  private

  # builds a url to prerecorded messages in the tropo account
  def isay msg
    AUDIO_URL + msg + AUDIO_TYPE
  end

  # if MAINTENANCE_MODE set to true, it plays the MAINTENANCE_MESSAGE and waits for you to dial the secret password ('8')
  def authorize_maintainance_mode
    unless @maintenance_authorized
      say *MAINTENANCE_MESSAGE
      ask("", {
            :choices => MAINTENANCE_PASSWORD,
            :mode => "dtmf",
            :timeout => 120.0,
            :onTimeout => :hangup,
            :onChoice => lambda {|event| maintenance_authorized!},
            :onBadChoice => lambda {|event| hangup! }
          })
      unless @maintenance_authorized
        log("Somebody called during maintenance: #{$currentCall.callerID}" )
        hangup!
      end
    end
  end

  
  # checks, if the dialed site number (e.g. '0012') exists SITES array
  # if yes: user is ask to verify the number
  # if not: user is taken back to enter the site number
  def check_store_and_verify_site_or_retry(choice_event)
    log("Result: #{choice_event.value} (event type: #{choice_event.name})") if DEBUG
    if SITES[choice_event.value]
      @site = {'id' => choice_event.value, 'data' => SITES[choice_event.value] }
      log("Found site #{choice_event.value} (#{@site.inspect})") if DEBUG
      verify_site
    else
      log("Didn't find site with number #{choice_event.value}}") if DEBUG
      get_site_info
    end
  end

  # ask user to verify the site number typed in
  def verify_site
    verification_prompt = isay("#{@site['id']}_Verification")

    options = @ask_default_options.merge(:choices => "1,2")

    event = ask(verification_prompt, options)
    if event.name == 'choice'
      if event.value == "1"
        caller_info['site_verified'] = true
      else
        get_site_info
      end
    else
      log("received #{event.name} and #{event.value} - retrying") if DEBUG
      get_site_info
    end
  end

  # ask user to dial the site number
  def get_site_info
    log "Currently trying to get site info." if DEBUG

    kick_out_after_too_many_retries_for!(:get_site_info)

    question = isay("1_1_Enter_4_digit_code_number")
    
    options = @ask_default_options.merge(:choices => "[4-DIGITS]")
    event = ask(question, options)
    check_store_and_verify_site_or_retry(event)
  end

  # options step 3
  def options_3
    prompts = isay('step3')
    log!('0#0#0##0#0#0#0#0#0#0#00# options 3')
    log!(prompts)
    say(prompts)
    log('-----------before option 3a')
  end
  
  #emergency_situation 3a #TODO timeout = ?!
  def option_3a_emergency  
    prompts = isay('step3a')
    options = @ask_default_options.merge(:choices => "0,1")
    log!('0#0#0##0#0#0#0#0#0#0#00# option 3a emergency')
    log!(prompts)
    event = ask(prompts, options)
    if event.value == '0'
      log!('-----------before urgent')
      urgent_action
      log!('-----------after urgent')
    else
      log!('-----------else urgent')
    end
  end

  # ask user for the incident code
  def get_incident_code_and_type!
    log!("---------------------------new incident options")
    @add_complain = true
    kick_out_after_too_many_retries_for!(:get_incident_code_and_type)

    # options step 3
    options_3
    
    #emergency_situation 3a #TODO timeout = ?!
    option_3a_emergency  
      
    #incident options step3 b,c,d,e
    ('b'..'f').each do |x|
      log!("----------############-----------------new incident")
      audio_file = "step3#{x}"
      prompts = isay(audio_file)
      options = @ask_default_options.merge(:choices => "1,2")
      log!("0#0#0##0#0#0#0#0#0#0#00# option 3#{x}")
      log(INCIDENTS[x])
      log!(prompts)
      event = ask(prompts, options)
      
      if event.value == '1'
        store_incident_code(x)
        incident_action!
        
        if @add_complain == false
          break
        end
      end
    end
    
    # ask for more complains at the end of all options to restart   
    #more_complains
    
  end

  # store the information of the caller
  def store_initial_caller_info
    caller_info['caller_number'] = $currentCall.callerID
    caller_info['retries'] = 0
    caller_info['network'] = $currentCall.network
    caller_info['caller_name'] = $currentCall.callerName if $currentCall.callerName
    log( "Caller: " + caller_info['caller_number'] ) if DEBUG
  end


  def more_complains
    prompts = isay('press_3_add_more_complaints')
    options = @ask_default_options.merge(:choices => "3,2")
    log!('0#0#0##0#0#0#0#0#0#0#00# add more complains?')
    log!(prompts)
    event = ask(prompts, options)
    if event.value == '2'
      @add_complain = false
    end
  end

  # section 1.4 in the specs
  # attention, the specs defined this to send a report for callback, instead we want to redirect
  def urgent_action
    phone = @site['data']['phone']
    transfer(phone, {:answerOnMedia => true})
  end

  # section 1.3 in the specs
  # ask user for amount of money
  def money_demanded

    kick_out_after_too_many_retries_for!(:money_demanded)

    question = isay("3_1_a__if_spent_less_that_500_or_more_than_500")
    options = @ask_default_options.merge(:choices => "1,2")
    event = ask(question, options)
    store_and_confirm_money_code(event)
  end


  # storing the dialed-in money code and ask for confirmation
  def store_and_confirm_money_code(event)

    log("trying to store money code") if DEBUG

    @money_code = event.value 
    
    unless MONEY_CODES[@money_code]
      log("Something went wrong - no valid money code, but still trying to store: #{event}") if DEBUG
      money_demanded
    end

    log("User choose money_code #{@money_code} (#{MONEY_CODES[@money_code]})") if DEBUG
    log("In site #{@site['id']}") if DEBUG

    confirm_money_code
  end

  # ask for confirmation of the money code
  def confirm_money_code

    kick_out_after_too_many_retries_for!(:confirm_money_code)

    question = isay(@site['id']+"_Money_Demanded_"+MONEY_CODES[@money_code])
    event = ask(question, @ask_default_options.merge(:choices => '1,2'))
    log("User choose #{event.inspect}") if DEBUG
    if event.value == "1"
      log("User confirmed amount of money") if DEBUG
      #byenow!
    else
      log('User did not confirm money code. Redirecting back to choosing incident') if DEBUG
      reset_retry_counts
      # send back to choose incident code
      get_incident_code_and_type!
    end
  end

  # def sorry_message(event)
  #   if DEBUG
  #     say("sorry! sending you back to the main menu")
  #     _log("We're in sorry_message, so something has gone horribly wrong!")
  #     caller_info.each_pair do |k,v|
  #       log("Key named: #{k} with value: #{v}")
  #     end
  #   end

  #   log("IVRS 0.3 - Caller at #{current_info['caller_number']} was unable to use the menu :(")
  #   say("ok, sending you back to the main menu!")
  #   wait(300);
  #   # TODO somethin shoud be called here, it's main in php
  # end

  # checks the dialed-in incident code, if '0' then urgent action is needed!
  def incident_action!
    log("getting the right action for incident") if DEBUG
    log("0#0#0##0#0#0#0#0#0#0#00# case incident action: #{@incident['id']}")
    case @incident['id']
    when 'b'..'e'
      money_demanded
      more_complains
    when 'f'
      money_demanded
    end
  end

  # stores the incident code
  def store_incident_code(choice_event)
    log("#{choice_event.inspect}")
    @incident ||= {}
    @incident['id'] = choice_event
    @incident['data'] = INCIDENTS[choice_event]
    log("##############################Incident is: #{@incident['id']}: #{@incident['data']}") if DEBUG
  end

  # sends the collected data to ushahidi/crowdmap
  def capture_data!
    client = UshahidiClient.new
    log("about to post report #{report} using #{client}") if DEBUG
    res = client.post_report(report)
    log("got this response from ushahidi: #{res}") if DEBUG
  end

  # collects the data in a report
  def report
    lat, lon = lat_lon
    description = @incident['data'].dup
    if money_description = MONEY_DESCRIPTION[@money_code]
      description << " #{money_description}"
    end
    report = {
      :title => @incident['data'],
      :category => '1',
      :latitude => lat,
      :longitude => lon,
      :description => description,
      :location_name => @site['data']['name']

    }
    log('##############report')
    log(report)
    return report
  end

  # gives back the lat/lon coordinates of the hospital
  def lat_lon
    @site['data']['location'].split(',')
  end

  # plays end message if all data was sucsessful collected, captures data and hangs up the call
  def byenow!
    say(isay("0_2_End_Message_1_Thank_You"))
    capture_data!
    hangup!
  end

  # hangs up the call
  def hangup!
    hangup
  end

  def log!(what)
    log(what) if DEBUG
  end
  

  # plays message when maintenance password is dialed in correctly
  def maintenance_authorized!
    @maintenance_authorized = true
    say "Maintenance mode entered. Warning, Hull breach imminent!"
  end

  # counts the number of retries for every question(action), kicks caller out if more then 2 retries
  def kick_out_after_too_many_retries_for!(action)
#    @retries[action] ||= 0
#    invalid_choice if @retries[action] > 2
#    @retries[action] += 1
#    log("=========================== Count for action '#{action}': #{@retries[action]}") if DEBUG 
  end

  # reset the retry counts
  def reset_retry_counts
    @retries.each_pair{|k,v| @retries[k] = 0}
    log("==== retry counts resetted") if DEBUG
  end

  # hangs up if more then 2 times a wrong choice is dialed
  def invalid_choice
    say(isay("0_3_End_Message_2_Not_entered_a_valid_choice"))
    hangup!
  end

end

# starts the script
Call.new.run


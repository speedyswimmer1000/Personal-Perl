#! /usr/bin/python

import mechanize, cookielib
import httplib, urllib2
import sys
from time import sleep

browser = mechanize.Browser()
browser.set_handle_robots(False)

##### SHAREBUILDER HISTORY FETCH #####

share_url = 'https://www.sharebuilder.com/sharebuilder/authentication/signin.aspx'
browser.open(share_url)

share_hist_file = str(sys.argv[1]) #tmp2		#Although tmp is a good name - it guarantees that there's nothing there you want to keep.

print browser.title()
form = browser.forms().next()  #Get the form
#print form  -- Useful for finding if the form field names have changed.
form['ctl00$ctl00$MainContent$MainContent$ucView$c$views$c$ucUsername$txtUsername']="swimmer1000"
form['ctl00$ctl00$MainContent$MainContent$ucView$c$views$c$ucUsername$txtPassword']="******** ADD IN CODE HERE " 
browser.form = form  #Give the filled in form back to the browser
browser.submit()
print browser.title()
#form = browser.forms().next()
#On to the password page
#browser.form = form
#browser.submit('ctl00$ctl00$MainContent$MainContent$ucView$c$views$c$btnNext') #Press the button!

buy_sell_hist = 'https://www.sharebuilder.com/sharebuilder/account/Records/History.aspx'
#Get the html of the transactions page, to be parsed by my perl script (OK, I'm more comfortable with perl. Sue me. :)
response = browser.open(buy_sell_hist)
content = response.read()
print browser.title()
transaction = open(share_hist_file, 'w')  #History file
transaction.write(content)


##### SCOTTRADE HISTORY FETCH #######
'''
scott_url = 'https://www.scottrade.com/'
browser.open(scott_url)

scott_hist_file = str(sys.argv[2]) #tmp or some such thing. Keeps the history file, to be parsed in perl because honestly I'm just more comfortable with it. 

#I get it. Browser() is a class that essentially opens up another browser, like firefox or chrome.
#As long as you navigate in that browser, you keep your login credentials, cookies, etc. 

print browser.title()
form = browser.forms().next()  #Get the form
#print form.action
form['account']="53057323"
form['password']="*****" 
browser.form = form  #Give the filled in form back to the browser
browser.submit()
print browser.title()

orders = "https://trading.scottrade.com/myaccount/OrderStatus.aspx"
response = browser.open(orders)
print browser.title()
content = response.read()

hist_file = open(scott_hist_file, 'w')
hist_file.write(content)
hist_file.close()
'''

##### MOTIF INVESTING FETCH #######

# motif_url = 'https://auth.motifinvesting.com/login'
# browser.open(motif_url)

# motif_hist_file = str(sys.argv[3])
# motif_file = open(motif_hist_file, 'w')

# print browser.title()
# form = browser.forms().next()
# form['email'] = 'benjamin.lewis.1000@gmail.com'
# form['password'] = '****'
# browser.form = form
# browser.submit()
# url = 'https://trader.motifinvesting.com/two_factor_auth?auth=1&next=%2Fhome'
# print browser.title()
# response = browser.open(url)
# content = response.read()
# browser.select_form(nr=1)
# motif_file.write(browser.submit().read())

# print browser.title()
# form = browser.select_form(nr=0)
# code = input("Enter the number: ")
# print code
# form['confirmCode'] = code


# motif_file.close()


#####################################  (Future accounts?)
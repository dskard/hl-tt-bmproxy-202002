import json
import time

# import the Selenium library to automate the web browser
from selenium import webdriver

# import the Selene library to help simplify browser automation
# Selene uses the Selenium library
from selene.api import browser, s, ss, be, have, by

# load libraries to communicate with the browsermob proxy
from browsermobproxy.client import Client

# set the url of the server under test
url = 'https://espn.com'

bmp_client = Client("bmp:18080")

# setup the proxy limits
bmp_client.limits({
    "downstream_kbps": 0,
    "upstream_kbps": 0,
    "latency": 0,
})

# start capturing HAR data
bmp_client.new_har(options={"captureHeaders": True, "captureContent": True})
bmp_client.new_page(ref="slow_internet")

# update the browser settings
capabilities = webdriver.DesiredCapabilities.FIREFOX.copy()
capabilities["acceptInsecureCerts"] = True
bmp_client.add_to_webdriver_capabilities(capabilities)

# launch the web browser
driver = webdriver.Remote("http://selenium-hub:4444/wd/hub", capabilities)
# give up to 10 minutes for the page to load
driver.set_page_load_timeout(600)
browser.set_driver(driver)

try:
    # navigate the web browser to the web application front page
    browser.open_url(url)
except Exception as ex:
    print(ex)
finally:
    # close the web browser
    browser.quit()

# save the har
with open(f'{int(time.time())}.har', 'w') as outfile:
    json.dump(bmp_client.har, outfile)

# kill the bmp client
bmp_client.close()


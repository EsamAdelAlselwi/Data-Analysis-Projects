from requests import Session
import json
import pandas as pd
import os
from time import sleep
import seaborn as sns
import matplotlib.pyplot as plt

api_key = os.environ.get("API_KEY")

def api_runner():
    url = 'https://pro-api.coinmarketcap.com/v1/cryptocurrency/listings/latest'
    parameters = {
      'start':'1',
      'limit':'15',
      'convert':'USD'
    }
    headers = {
      'Accepts': 'application/json',
      'X-CMC_PRO_API_KEY': api_key,
    }

    session = Session()
    session.headers.update(headers)

    response = session.get(url, params=parameters)
    global data
    data = json.loads(response.text)

   
    pd.set_option('display.max_columns', None)

api_runner()
df = pd.json_normalize(data['data'])
df['timestamp'] = pd.to_datetime('now')

for i in range(333):
    api_runner()
    df2 = pd.json_normalize(data['data'])
    df2['timestamp'] = pd.to_datetime('now')
    df = df.append(df2)
    if not os.path.isfile("/Users/denisechan/PycharmProjects/Alex-The-Analyst/Automating Crypto Website API Pull/API.csv"):
        df.to_csv("/Users/denisechan/PycharmProjects/Alex-The-Analyst/Automating Crypto Website API Pull/API.csv", header='column_names')
    else:
        df.to_csv("/Users/denisechan/PycharmProjects/Alex-The-Analyst/Automating Crypto Website API Pull/API.csv", mode='a', header=False)
    print("API runner completed!")
    sleep(60)


pd.set_option('display.float_format', lambda x: '%.5f' % x)
df3 = df.groupby('name', sort=False)[['quote.USD.percent_change_1h','quote.USD.percent_change_24h','quote.USD.percent_change_7d','quote.USD.percent_change_30d','quote.USD.percent_change_60d','quote.USD.percent_change_90d']].mean()
df4 = df3.stack()
df5 = df4.to_frame(name='values')
df6 = df5.reset_index()
df7 = df6.rename(columns={'level_1': 'percent_change'})
df7['percent_change'] = df7['percent_change'].replace(['quote.USD.percent_change_1h','quote.USD.percent_change_24h','quote.USD.percent_change_7d','quote.USD.percent_change_30d','quote.USD.percent_change_60d','quote.USD.percent_change_90d'],['1h','24h','7d','30d','60d','90d'])
print(df7)

sns.catplot(x='percent_change', y='values', hue='name', data=df7, kind='point')
plt.show()

df10 = df[['name', 'quote.USD.price', 'timestamp']]
df10 = df10.query("name == 'Bitcoin'")
print(df10)

sns.set_theme(style="darkgrid")
sns.lineplot(x='timestamp', y='quote.USD.price', data=df10)
plt.show()
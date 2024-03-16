import React from 'react';
import ReactDOM from 'react-dom';
import './index.css';
import App from './App';
import registerServiceWorker from './registerServiceWorker';
import { ApolloProvider } from '@apollo/client';
import { AgostonClient } from '@agoston-io/client'


AgostonClient({
  backendUrl: 'https://graphile.agoston-dev.io',
}).then(async agostonClient => {

  if (agostonClient.isAuthenticated()) {
    console.log(`Welcome user ${agostonClient.userId()} 👋! Your role is: ${agostonClient.userRole()}.`);
  }

  const apolloClient = await agostonClient.createEmbeddedApolloClient();

  const ApolloApp = AppComponent => (
    <ApolloProvider client={apolloClient}>
      <AppComponent />
    </ApolloProvider>
  );

  ReactDOM.render(ApolloApp(App), document.getElementById('root'));
  registerServiceWorker();
});



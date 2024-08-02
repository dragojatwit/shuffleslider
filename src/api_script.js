/**
 * This is an example of a basic node.js script that performs
 * the Authorization Code with PKCE oAuth2 flow to authenticate 
 * against the Spotify Accounts.
 *
 * For more information, read
 * https://developer.spotify.com/documentation/web-api/tutorials/code-pkce-flow
 */

const clientId = '268490de207a4fadaf8ab5172f455698'; // your clientId
const redirectUrl = 'http://localhost:5173/callback';        // your redirect URL - must be localhost URL and/or HTTPS

const authorizationEndpoint = "https://accounts.spotify.com/authorize";
const tokenEndpoint = "https://accounts.spotify.com/api/token";
const scope = 'user-read-private user-read-email';

// Data structure that manages the current active token, caching it in localStorage
const currentToken = {
  get access_token() { return localStorage.getItem('access_token') || null; },
  get refresh_token() { return localStorage.getItem('refresh_token') || null; },
  get expires_in() { return localStorage.getItem('refresh_in') || null },
  get expires() { return localStorage.getItem('expires') || null },

  save: function (response) {
    const { access_token, refresh_token, expires_in } = response;
    localStorage.setItem('access_token', access_token);
    localStorage.setItem('refresh_token', refresh_token);
    localStorage.setItem('expires_in', expires_in);

    const now = new Date();
    const expiry = new Date(now.getTime() + (expires_in * 1000));
    localStorage.setItem('expires', expiry);
  }
};

// On page load, try to fetch auth code from current browser search URL
const args = new URLSearchParams(window.location.search);
const code = args.get('code');

// If we find a code, we're in a callback, do a token exchange
if (code) {
  const token = await getToken(code);
  currentToken.save(token);

  // Remove code from URL so we can refresh correctly.
  const url = new URL(window.location.href);
  url.searchParams.delete("code");

  const updatedUrl = url.search ? url.href : url.href.replace('?', '');
  window.history.replaceState({}, document.title, updatedUrl);
}

// If we have a token, we're logged in, so fetch user data and render logged in template
if (currentToken.access_token) {
  const userData = await getUserData();
  const playlistData = await getPlaylistData(userData);

  console.log(playlistData);
  renderTemplate("main", "logged-in-template", userData);
  renderTemplate("secondary", "userPlaylists", playlistData);
}

// Otherwise we're not logged in, so render the login template
if (!currentToken.access_token) {
  renderTemplate("main", "login");
}

async function redirectToSpotifyAuthorize() {
  const possible = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  const randomValues = crypto.getRandomValues(new Uint8Array(64));
  const randomString = randomValues.reduce((acc, x) => acc + possible[x % possible.length], "");

  const code_verifier = randomString;
  const data = new TextEncoder().encode(code_verifier);
  const hashed = await crypto.subtle.digest('SHA-256', data);

  const code_challenge_base64 = btoa(String.fromCharCode(...new Uint8Array(hashed)))
    .replace(/=/g, '')
    .replace(/\+/g, '-')
    .replace(/\//g, '_');

  window.localStorage.setItem('code_verifier', code_verifier);

  const authUrl = new URL(authorizationEndpoint)
  const params = {
    response_type: 'code',
    client_id: clientId,
    scope: scope,
    code_challenge_method: 'S256',
    code_challenge: code_challenge_base64,
    redirect_uri: redirectUrl,
  };

  authUrl.search = new URLSearchParams(params).toString();
  window.location.href = authUrl.toString(); // Redirect the user to the authorization server for login
}

// Soptify API Calls
async function getToken(code) {
  const code_verifier = localStorage.getItem('code_verifier');

  const response = await fetch(tokenEndpoint, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: new URLSearchParams({
      client_id: clientId,
      grant_type: 'authorization_code',
      code: code,
      redirect_uri: redirectUrl,
      code_verifier: code_verifier,
    }),
  });

  return await response.json();
}

async function refreshToken() {
  const response = await fetch(tokenEndpoint, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded'
    },
    body: new URLSearchParams({
      client_id: clientId,
      grant_type: 'refresh_token',
      refresh_token: currentToken.refresh_token
    }),
  });

  return await response.json();
}

async function ensureValidToken() {
  const now = new Date();
  const expiry = new Date(localStorage.getItem('expires'));

  if (now >= expiry) {
    const tokenData = await refreshToken();
    currentToken.save(tokenData);
  }
}


async function getUserData() {
  await ensureValidToken();
  const response = await fetch("https://api.spotify.com/v1/me", {
    method: 'GET',
    headers: { 'Authorization': 'Bearer ' + currentToken.access_token },
  });

  return await response.json();
}

async function getPlaylistData(userData) {
  await ensureValidToken();
  const userID = userData.id;
  const response = await fetch(`https://api.spotify.com/v1/users/${userID}/playlists`, {
    method: 'GET',
    headers: {
      'Authorization': 'Bearer ' + currentToken.access_token,
    },
  });

  return await response.json();
}

async function getPlaylistTracks(playlistData) {
  await ensureValidToken();
  const playlistID = playlistData.id;
  const url = `https://api.spotify.com/v1/playlists/${playlistID}/tracks`;
  
  try {
      const response = await fetch(url, {
          method: 'GET',
          headers: {
              'Authorization': `Bearer ${currentToken.access_token}`,
          }
      });

      if (!response.ok) {
          throw new Error(`HTTP error! Status: ${response.status}`);
      }

      const parsedResponse = await response.json();

      if (parsedResponse.items.length === 0) {
          throw new Error('The playlist is empty.');
      }

      const firstTrack = parsedResponse.items[0].track;

      if (!firstTrack || !firstTrack.preview_url) {
          throw new Error('First track does not have a preview URL.');
      }
      
      return firstTrack.id;
  } catch (error) {
      console.error('Error fetching playlist tracks:', error);
      return null; // or handle the error as needed
  }
}


//collects audio features to be ran against machine learning algorithm
async function getTrackData(trackId){
  await ensureValidToken();
    const url = `https://api.spotify.com/v1/audio-features/${trackId}`
    console.log(url);   
    try {
      const response = await fetch(url, {
          method: 'GET',
          headers: {
              'Authorization': `Bearer ${currentToken.access_token}`,
          }
      });

      if (!response.ok) {
          throw new Error(`HTTP error! Status: ${response.status}`);
      }

      const parsedResponse = await response.json();
      console.log(parsedResponse);
      return parsedResponse;

    } catch (error) {
        console.error('Error fetching track audio features:', error);
        return null; // or handle the error as needed
    }
}

//collects track artist for the purpose of getting genre
async function getTrackArtist(trackId){
  await ensureValidToken();
    const track_url = `https://api.spotify.com/v1/tracks/${trackId}`
    try {
      const response = await fetch(track_url, {
          method: 'GET',
          headers: {
              'Authorization': `Bearer ${currentToken.access_token}`,
          }
      });

      if (!response.ok) {
          throw new Error(`HTTP error! Status: ${response.status}`);
      }

      const parsedResponse = await response.json();
      console.log(parsedResponse);
      return parsedResponse.artists[0].id;


    } catch (error) {
        console.error('Error fetching track artist:', error);
        return null; // or handle the error as needed
    }
}

//collects artist genre for the purpose of attaching it to their track
async function getArtistGenre(artistId){
  await ensureValidToken();
    const url = `https://api.spotify.com/v1/artists/${artistId}`
    try {
      const response = await fetch(url, {
          method: 'GET',
          headers: {
              'Authorization': `Bearer ${currentToken.access_token}`,
          }
      });

      if (!response.ok) {
          throw new Error(`HTTP error! Status: ${response.status}`);
      }

      const parsedResponse = await response.json();
      console.log(parsedResponse);
      return parsedResponse.genres[0];


    } catch (error) {
        console.error('Error fetching artist genre:', error);
        return null; // or handle the error as needed
    }
}

// Click handlers
async function loginWithSpotifyClick() {
  await redirectToSpotifyAuthorize();
}

async function logoutClick() {
  localStorage.clear();
  window.location.href = redirectUrl;
}

function renderTemplate(targetId, templateId, data = null) {
    const template = document.getElementById(templateId);
    const clone = template.content.cloneNode(true);
  
    if (templateId === "userPlaylists" && data) {
      console.log("loaded user playlists");  
      const playlistTableBody = clone.getElementById("playlistTableBody");

        data.items.forEach(item => {
        const tr = document.createElement("tr");
        
        const tdImage = document.createElement("td");
        if (item.images.length > 0) {
          const img = document.createElement("img");
          img.src = item.images[0].url; // Assuming the first image is the cover
          img.alt = item.name;
          img.width = 50; // Set width as needed
          img.height = 50;
          tdImage.appendChild(img);
        } else {
          // Placeholder if no image available
          tdImage.textContent = "No Image";
        }
        tr.appendChild(tdImage);

        const tdTitle = document.createElement("td");
        tdTitle.textContent = item.name;
        tdTitle.class = "playlist-title";

        tr.appendChild(tdTitle);

        const td = document.createElement("td");
        const selectPlaylist = document.createElement("button");

        selectPlaylist.id = "selectPlaylist";
        
        selectPlaylist.textContent = "Select";
        console.log(item);
        selectPlaylist.addEventListener("click", () => {
            renderTemplate("secondary","slider",item);
        });
        
        td.appendChild(selectPlaylist);
        tr.appendChild(td);

        playlistTableBody.appendChild(tr);
      });
    }

    if(templateId == "slider" && data){

      //data in this context refers to the single selected playlist
      const selectedPlaylist = clone.getElementById("playlistDisplay");
      const playlistName = document.createElement("th");

      const backButton = clone.getElementById("returnToPL");
      backButton.addEventListener("click", () => {
        history.back();
      });

      const submitButton = clone.getElementById("submitForRec");
      submitButton.addEventListener("click", async () => {
        const recSongExtract = await getPlaylistTracks(data);
        const trackAudioValues = await getTrackData(recSongExtract);
        const sliderValue = document.getElementById("theSlider").value;
        const rec = await callToR(trackAudioValues,sliderValue);
        //const rec = "spotify:track:26I6RaeZZrIMyGAUwfNCxo";
        
        renderTemplate("secondary","recommendation",rec);
        renderEmbed(rec);
      })

      playlistName.textContent = data.name;

      console.log(selectedPlaylist);

      const playlistImage = document.createElement("th");
      if (data.images.length > 0) {
        const img = document.createElement("img");
        img.src = data.images[0].url; 
        img.alt = data.name;
        img.width = 50; 
        img.height = 50;
        playlistImage.appendChild(img);
      } else {
        // Placeholder if no image available
        playlistImage.textContent = "No Image";
      }
      console.log(playlistImage);
      
      selectedPlaylist.appendChild(playlistImage);
      selectedPlaylist.appendChild(playlistName);

    }

    if(templateId == "recommendation")
    {
      const restart = clone.getElementById("restartButton");
      console.log("restarted");
      restart.addEventListener("click",() => {
        logoutClick();
        
      } )
    }

    const elements = clone.querySelectorAll("*");
    elements.forEach(ele => {
      const bindingAttrs = [...ele.attributes].filter(a => a.name.startsWith("data-bind"));
  
      bindingAttrs.forEach(attr => {
        const target = attr.name.replace(/data-bind-/, "").replace(/data-bind/, "");
        const targetType = target.startsWith("onclick") ? "HANDLER" : "PROPERTY";
        const targetProp = target === "" ? "innerHTML" : target;
  
        const prefix = targetType === "PROPERTY" ? "data." : "";
        const expression = prefix + attr.value.replace(/;\n\r\n/g, "");
  
        // Maybe use a framework with more validation here ;)
        try {
          ele[targetProp] = targetType === "PROPERTY" ? eval(expression) : () => { eval(expression) };
          ele.removeAttribute(attr.name);
        } catch (ex) {
          console.error(`Error binding ${expression} to ${targetProp}`, ex);
        }
      });
    });
  
    const target = document.getElementById(targetId);
    target.innerHTML = "";
    target.appendChild(clone);
  }

  function renderEmbed(rec)
  {
    //from spotify for devs
    window.onSpotifyIframeApiReady = (IFrameAPI) => {
      const element = document.getElementById('recommendationEmbed');
      const options = {
          uri: rec
        };
      const callback = (EmbedController) => {};
      IFrameAPI.createController(element, options, callback);
    };
    
    

  }

  async function callToR(songData, sliderValue) {
    
    const Surl = 'http://localhost:5555/process';
    const Rurl = 'http://localhost:5555/recommend';
    
    //Spotify only attaches genres to artists, have to grab the artist data first and then their genre
    const artistId = await getTrackArtist(songData.id);
    const genre = await getArtistGenre(artistId);

    const defaultValues = {
      id : songData.id,
      popularity : 0.5,
      duration_ms : 150000.0,
      danceability : 0.5,
      energy : 0.5,
      loudness : -30,
      speechiness : 0.5,
      acousticness : 0.5,
      instrumentalness : 0.5,
      liveness : 0.5,
      valence : 0.5,
      tempo : 120,
      sliderValue: 5

    };


    const data = {
      ...defaultValues,

      id : songData.id,
      popularity : songData.popularity !== null && songData.popularity !== undefined ? popularity : defaultValues.popularity ,
      duration_ms : songData.duration_ms,
      danceability : songData.danceability,
      energy : songData.energy,
      loudness : songData.loudness,
      speechiness : songData.speechiness,
      acousticness : songData.acousticness,
      instrumentalness : songData.instrumentalness,
      liveness : songData.liveness,
      valence : songData.valence,
      tempo : songData.tempo,
      sliderValue: sliderValue
    }
    console.log(data)

    //Send Data to R
    try {
      const response = await fetch(Surl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(data)
      })

      console.log(response);
    }
    catch (error) {
      console.error('Error:', error);
    }
    //Receiving data back from R
    try {
      const response = await fetch(Rurl, {
        method: 'GET',
        headers: {
          'Content-Type': 'application/json',
        },
      });
  
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }
  
      
      // Parse the response body as JSON
      const rdata = await response.json();
      console.log('Full response:', rdata);

      // Extract the 'uri' field
      const uri = rdata[0].uri;
      console.log('Extracted URI:', uri);

      return uri;

  
    } catch (error) {
      console.error('Error:', error);
    }
  }
  

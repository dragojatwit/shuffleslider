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

async function getUserData() {
  const response = await fetch("https://api.spotify.com/v1/me", {
    method: 'GET',
    headers: { 'Authorization': 'Bearer ' + currentToken.access_token },
  });

  return await response.json();
}

async function getPlaylistData(userData) {
  const userID = userData.id;
  const response = await fetch(`https://api.spotify.com/v1/users/${userID}/playlists`, {
    method: 'GET',
    headers: {
      'Authorization': 'Bearer ' + currentToken.access_token,
    },
  });

  return await response.json();
}


// Click handlers
async function loginWithSpotifyClick() {
  await redirectToSpotifyAuthorize();
}

async function logoutClick() {
  localStorage.clear();
  window.location.href = redirectUrl;
}

// async function refreshTokenClick() {
//   const token = await refreshToken();
//   currentToken.save(token);
//   renderTemplate("oauth", "oauth-template", currentToken);
// }

// function templateRenderer(targetId, templateId, data = null)
// {
//   const template = document.getElementById(templateId);
//   const cloneTemplate = template.content.cloneNode(true);

  

//   cloneTemplate.appendChild(data[1].name)

//   const target = document.getElementById(targetId);
//   target.innerHTML = "";
//   target.appendChild(clone);
// }

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

        const td = document.createElement("td");
        const selectPlaylist = document.createElement("button");

        selectPlaylist.id = "selectPlaylist";
        selectPlaylist.textContent = item.name;
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

      // const submitButton = clone.getElementById("submitForRec");
      // submitButton.addEventListener("click", () => {
      //   const rec = callToR(data);
      //   renderTemplate('secondary','reccomendation',rec)
      // })

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


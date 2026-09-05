const sdkBase = 'https://www.gstatic.com/firebasejs/12.15.0';

async function startApp() {
  try {
    const [core, firestore, auth] = await Promise.all([
      import(`${sdkBase}/firebase-app.js`),
      import(`${sdkBase}/firebase-firestore-pipelines.js`),
      import(`${sdkBase}/firebase-auth.js`),
    ]);

    globalThis.firebase_core = core;
    globalThis.firebase_firestore = firestore;
    globalThis.firebase_auth = auth;

    const flutterScript = document.createElement('script');
    flutterScript.src = 'flutter_bootstrap.js';
    flutterScript.async = true;
    flutterScript.addEventListener('error', showStartupError);
    document.body.appendChild(flutterScript);
  } catch (error) {
    console.error('App service startup failed.', error);
    showStartupError();
  }
}

function showStartupError() {
  const copy = document.querySelector('.loading-copy');
  const track = document.querySelector('.loading-track');
  if (copy) copy.textContent = 'Unable to start the secure workspace.';
  if (track) {
    track.innerHTML = '';
    const retry = document.createElement('button');
    retry.type = 'button';
    retry.textContent = 'Try again';
    retry.addEventListener('click', () => window.location.reload());
    retry.style.cssText = [
      'border:0',
      'border-radius:8px',
      'padding:11px 18px',
      'background:#47b37b',
      'color:#101518',
      'font:700 14px Arial,sans-serif',
      'cursor:pointer',
    ].join(';');
    track.style.height = 'auto';
    track.style.overflow = 'visible';
    track.style.background = 'transparent';
    track.appendChild(retry);
  }
}

startApp();

(() => {
  "use strict";

  const MAX_BYTES = 25000000;
  const MAX_MS = 1800000;

  let recorder = null;
  let stream = null;
  let completion = null;
  let timer = null;
  let generation = 0;
  let pending = false;
  let player = null;
  let playbackUrl = null;

  function stopTracks(value) {
    if (value) {
      value.getTracks().forEach(track => track.stop());
    }
  }

  function stopPlayback() {
    if (player) {
      player.pause();
      player.removeAttribute("src");
      player.load();
      player = null;
    }
    if (playbackUrl) {
      URL.revokeObjectURL(playbackUrl);
      playbackUrl = null;
    }
  }

  function cancel() {
    generation++;
    pending = false;
    clearTimeout(timer);

    if (recorder && recorder.state !== "inactive") {
      recorder.stop();
    }

    stopTracks(stream);
    recorder = null;
    stream = null;
    completion = null;
    stopPlayback();
  }

  async function start() {
    if (pending || recorder) {
      throw new Error("Recording is already active.");
    }

    if (!navigator.mediaDevices?.getUserMedia ||
        typeof MediaRecorder === "undefined") {
      throw new Error("Microphone recording is unavailable.");
    }

    const mimeType = ["audio/webm;codecs=opus", "audio/webm"]
      .find(type => MediaRecorder.isTypeSupported(type));

    if (!mimeType) {
      throw new Error("WebM recording is unsupported. Upload an audio file instead.");
    }

    stopPlayback();

    const current = ++generation;
    pending = true;
    let acquired = null;

    try {
      acquired = await navigator.mediaDevices.getUserMedia({
        audio: true,
        video: false
      });

      if (current !== generation) {
        stopTracks(acquired);
        throw new Error("Recording was cancelled.");
      }

      stream = acquired;

      const active = new MediaRecorder(acquired, {
        mimeType,
        audioBitsPerSecond: 64000
      });

      recorder = active;

      const chunks = [];
      let size = 0;
      let failure = null;
      let started = 0;

      completion = new Promise((resolve, reject) => {
        active.ondataavailable = event => {
          if (event.data.size === 0 || failure) return;

          size += event.data.size;

          if (size > MAX_BYTES) {
            failure = new Error("Recording exceeds 25 MB.");

            if (active.state !== "inactive") active.stop();

            return;
          }

          chunks.push(event.data);
        };

        active.onerror = () => {
          failure = new Error("Microphone recording failed.");

          if (active.state !== "inactive") active.stop();
        };

        active.onstop = async () => {
          const elapsed = performance.now() - started;

          if (current === generation) {
            clearTimeout(timer);
            stopTracks(acquired);
            stream = null;
          } else {
            stopTracks(acquired);
          }

          try {
            if (current !== generation) {
              throw new Error("Recording was cancelled.");
            }

            if (failure) throw failure;

            const blob = new Blob(chunks, {
              type: active.mimeType
            });

            if (!blob.size || blob.size > MAX_BYTES) {
              throw new Error("Invalid recording size.");
            }

            const bytes = new Uint8Array(await blob.arrayBuffer());

            if (current !== generation) {
              throw new Error("Recording was cancelled.");
            }

            resolve({
              bytes,
              seconds: Math.min(
                1800,
                Math.max(1, Math.ceil(elapsed / 1000))
              )
            });
          } catch (error) {
            reject(error);
          }
        };
      });

      // Prevent unhandled errors before Stop is pressed.
      completion.catch(() => {});

      started = performance.now();
      active.start(1000);

      timer = setTimeout(() => {
        if (active.state !== "inactive") active.stop();
      }, MAX_MS);

      return true;
    } catch (error) {
      stopTracks(acquired);

      if (current === generation) {
        recorder = null;
        stream = null;
        completion = null;
      }

      throw error;
    } finally {
      if (current === generation) pending = false;
    }
  }

  async function stop() {
    if (!recorder || !completion) {
      throw new Error("No active recording.");
    }

    const current = generation;
    const result = completion;

    if (recorder.state !== "inactive") {
      recorder.stop();
    }

    try {
      return await result;
    } finally {
      if (current === generation) {
        recorder = null;
        completion = null;
      }
    }
  }

  async function play(bytes) {
    stopPlayback();

    playbackUrl = URL.createObjectURL(
      new Blob([bytes], { type: "audio/webm" })
    );

    player = new Audio(playbackUrl);

    player.onended = stopPlayback;
    player.onerror = stopPlayback;

    try {
      await player.play();
      return true;
    } catch (error) {
      stopPlayback();
      throw error;
    }
  }

  window.reqvioraVoiceRecorder = {
    start,
    stop,
    cancel,
    play,
    stopPlayback
  };

  window.addEventListener("pagehide", cancel);
})();
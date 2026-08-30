Module.register("MMM-TuAsistente", {

  defaults: {
    model: "qwen2.5:1.5b",
    hideDelay: 5000
  },


  // ==========================================================
  // STYLES
  // ==========================================================

  getStyles: function () {
    return ["MMM-TuAsistente.css"];
  },


  // ==========================================================
  // START
  // ==========================================================

  start: function () {

    this.userQuery = "";
    this.assistantResponse = "";

    this.currentState = "hidden";

    // --------------------------------------------------------
    // IMAGEN
    // --------------------------------------------------------

    this.imageUrl = null;
    this.imageQuery = "";
    this.imageTimer = null;

    // --------------------------------------------------------
    // YOUTUBE
    // --------------------------------------------------------

    this.youtubeVideoId = null;
    this.youtubePlayer = null;
    this.youtubeApiReady = false;

    // Control de pantalla completa de YouTube
    this.youtubeFullscreen = false;

    // --------------------------------------------------------
    // TEMPORIZADOR GENERAL
    // --------------------------------------------------------

    this.hideTimer = null;

    // --------------------------------------------------------
    // VOLUMEN
    // --------------------------------------------------------

    this.volumeStatus = "";
    this.volumeLevel = 0;
    this.volumeMuted = false;
    this.volumeTimer = null;
    this.volumeCommandActive = false;

    // --------------------------------------------------------
    // SPOTIFY
    // --------------------------------------------------------

    this.spotifyEvent = null;

    // ========================================================
    // CONFIG
    // ========================================================

    this.sendSocketNotification(
      "INIT_CONFIG",
      this.config
    );


    // ========================================================
    // YOUTUBE API
    // ========================================================

    if (!window.YT) {

      const tag =
        document.createElement("script");

      tag.src =
        "https://www.youtube.com/iframe_api";

      document.head.appendChild(tag);
    }

    window.onYouTubeIframeAPIReady = () => {

      this.youtubeApiReady = true;

    };
  },


  // ==========================================================
  // IMAGEN SEGÚN ESTADO
  // ==========================================================

  getImageForState: function (state) {

    switch (state) {

      case "recording":
        return "images/recording.jpg";

      case "video":
      case "thinking":
      case "speaking":
      default:
        return "images/thinking.png";
    }
  },


  // ==========================================================
  // SOCKET
  // ==========================================================

  socketNotificationReceived:
    function (notification, payload) {


    // ========================================================
    // ESTADO
    // ========================================================

    if (notification === "STATUS") {

      // ------------------------------------------------------
      // GRABANDO
      // ------------------------------------------------------

      if (
        typeof payload === "string" &&
        payload.includes("Grabando")
      ) {

        if (this.hideTimer) {

          clearTimeout(this.hideTimer);
          this.hideTimer = null;
        }


        // Si empieza una nueva interacción,
        // cancelar imagen anterior.

        if (this.imageTimer) {

          clearTimeout(this.imageTimer);
          this.imageTimer = null;
        }

        this.imageUrl = null;
        this.imageQuery = "";


        this.currentState = "recording";

        this.assistantResponse = "";
        this.userQuery = "";

        this.updateDom(200);
      }


      // ------------------------------------------------------
      // PENSANDO
      // ------------------------------------------------------

      else if (
        typeof payload === "string" &&
        payload.includes("Pensando")
      ) {

        this.currentState = "thinking";

        this.updateDom(200);
      }


      // ------------------------------------------------------
      // CANCELADO / ERROR
      // ------------------------------------------------------

      else if (
        payload === "CANCELLED" ||
        payload === "ERROR"
      ) {

        if (this.hideTimer) {

          clearTimeout(this.hideTimer);
          this.hideTimer = null;
        }


        if (this.imageTimer) {

          clearTimeout(this.imageTimer);
          this.imageTimer = null;
        }


        this.imageUrl = null;
        this.imageQuery = "";


        if (this.currentState !== "video") {

          this.currentState = "hidden";
        }


        this.userQuery = "";
        this.assistantResponse = "";

        this.updateDom(200);
      }
    }


    // ========================================================
    // SPOTIFY / LIBRESPOT
    // ========================================================

    else if (
      notification === "SPOTIFY_EVENT"
    ) {

      console.log(
        "[MMM-TuAsistente] Evento Spotify recibido:",
        payload
      );

      // Guardamos el estado para usarlo posteriormente
      this.spotifyEvent = payload || {};

      // ======================================================
      // TEMPORIZADOR SPOTIFY
      // ======================================================

      // Si vuelve a reproducir, cancelamos el temporizador
      if (
        this.spotifyEvent.event === "playing" ||
        this.spotifyEvent.event === "track_changed"
      ) {

        if (this.spotifyPauseTimer) {
          clearTimeout(this.spotifyPauseTimer);
          this.spotifyPauseTimer = null;
        }
      }

      // Si se pausa, esperamos 10 segundos antes de ocultar
      if (
        this.spotifyEvent.event === "paused"
      ) {

        if (this.spotifyPauseTimer) {
          clearTimeout(this.spotifyPauseTimer);
        }

        this.spotifyPauseTimer =
          setTimeout(() => {

            const spotifyCard =
              document.getElementById(
                "mmm-tu-asistente-spotify"
              );

            if (spotifyCard) {
              spotifyCard.remove();
            }

            this.spotifyPauseTimer = null;

          }, 10000);
      }

      this.updateDom(100);
    }


    // ========================================================
    // VOLUMEN
    // ========================================================

    else if (
      notification === "VOLUME_STATUS"
    ) {

      // ------------------------------------------------------
      // RECIBIR VOLUMEN
      // ------------------------------------------------------

      this.volumeStatus =
        payload && payload.text
          ? payload.text
          : "";


      this.volumeMuted =
        payload &&
        payload.muted === true;


      this.volumeLevel =
        payload &&
        Number.isFinite(
          Number(payload.volume)
        )
          ? Number(payload.volume)
          : 0;


      // ------------------------------------------------------
      // CANCELAR TEMPORIZADOR
      // ------------------------------------------------------

      if (this.volumeTimer) {

        clearTimeout(this.volumeTimer);
        this.volumeTimer = null;
      }


      // ------------------------------------------------------
      // MOSTRAR INMEDIATAMENTE
      // ------------------------------------------------------

      this.updateDom(200);


      // ------------------------------------------------------
      // MUTE
      //
      // Si está silenciado NO desaparece.
      // ------------------------------------------------------

      if (this.volumeMuted) {

        return;
      }


      // ------------------------------------------------------
      // VOLUMEN NORMAL
      //
      // Desaparece después de 5 segundos.
      // ------------------------------------------------------

      if (this.volumeStatus) {

        this.volumeTimer =
          setTimeout(() => {

            this.volumeStatus = "";
            this.volumeTimer = null;

            this.updateDom(200);

          }, 5000);
      }
    }


    // ========================================================
    // PREGUNTA DEL USUARIO
    // ========================================================

    else if (
      notification === "USER_QUERY"
    ) {

      this.userQuery =
        payload || "";

      this.updateDom(200);
    }


    // ========================================================
    // RESPUESTA DEL ASISTENTE
    // ========================================================

   else if (
  notification === "ASSISTANT_RESPONSE"
) {

  this.assistantResponse =
    payload || "";

  // ======================================================
  // SI ES UNA ORDEN DE VOLUMEN
  // NO CAMBIAR LA IMAGEN NI OCULTAR EL ASISTENTE
  // ======================================================

  if (this.volumeCommandActive) {

    this.updateDom(200);

    return;
  }


  // ======================================================
  // COMPORTAMIENTO NORMAL
  // ======================================================

  if (
    this.currentState !== "video" &&
    this.currentState !== "image"
  ) {

    this.currentState =
      "speaking";
  }

  this.updateDom(200);


  if (
    this.currentState !== "video" &&
    this.currentState !== "image"
  ) {

    if (this.hideTimer) {
      clearTimeout(this.hideTimer);
    }

    this.hideTimer =
      setTimeout(() => {

        this.currentState =
          "hidden";

        this.userQuery = "";
        this.assistantResponse = "";

        this.updateDom(500);

      }, this.config.hideDelay);
  }
}

        // ========================================================
    // MOSTRAR IMAGEN
    // ========================================================

    else if (
      notification === "SHOW_IMAGE"
    ) {

      // Cancelar temporizador anterior
      if (this.imageTimer) {
        clearTimeout(this.imageTimer);
        this.imageTimer = null;
      }

      // Guardar imagen
      this.imageUrl =
        payload && payload.url
          ? payload.url
          : null;

      this.imageQuery =
        payload && payload.query
          ? payload.query
          : "";

      // Si no hay imagen v�lida, no mostrar nada
      if (!this.imageUrl) {
        this.currentState = "hidden";
        this.updateDom(200);
        return;
      }

      console.log(
        "[MMM-TuAsistente] Mostrando imagen:",
        this.imageUrl
      );

      // Mostrar �nicamente la imagen
      this.currentState = "image";

      this.userQuery = "";
      this.assistantResponse = "";

      this.updateDom(300);

      // ======================================================
      // OCULTAR IMAGEN AUTOM�TICAMENTE
      // ======================================================

      this.imageTimer = setTimeout(() => {

        console.log(
          "[MMM-TuAsistente] Ocultando imagen"
        );

        this.imageUrl = null;
        this.imageQuery = "";

        this.imageTimer = null;

        // Volver al estado oculto
        this.currentState = "hidden";

        this.userQuery = "";
        this.assistantResponse = "";

        // IMPORTANTE:
        // No tocar:
        // this.volumeStatus
        // this.volumeMuted
        // this.volumeLevel

        this.updateDom(300);

      }, 10000);
    }

    // ========================================================
    // YOUTUBE
    // ========================================================

    else if (
      notification === "PLAY_YOUTUBE"
    ) {

      if (this.hideTimer) {

        clearTimeout(this.hideTimer);
        this.hideTimer = null;
      }


      if (this.imageTimer) {

        clearTimeout(this.imageTimer);
        this.imageTimer = null;
      }


      this.imageUrl = null;
      this.imageQuery = "";


      this.youtubeVideoId =
        payload && payload.videoId
          ? payload.videoId
          : null;


      this.youtubeFullscreen =
        payload && payload.fullscreen
          ? true
          : false;


      console.log(
        "[MMM-TuAsistente] YouTube fullscreen:",
        this.youtubeFullscreen
      );


      this.currentState =
        "video";

      this.userQuery = "";
      this.assistantResponse = "";


      /*
       * FULLSCREEN REAL
       *
       * Se crea directamente en document.body
       * para evitar los contenedores de MagicMirror.
       */

      if (
        this.youtubeFullscreen &&
        this.youtubeVideoId
      ) {

        this.createYouTubeFullscreen();

        return;
      }


      /*
       * YOUTUBE NORMAL
       */

      this.updateDom(300);


      setTimeout(() => {

        this.initYouTubePlayer();

      }, 500);
    }


    // ========================================================
    // DETENER YOUTUBE
    // ========================================================

    else if (
      notification === "STOP_YOUTUBE"
    ) {

      this.youtubeVideoId = null;
      this.youtubePlayer = null;

      this.youtubeFullscreen = false;

      this.removeYouTubeFullscreen();


      this.currentState =
        "hidden";

      this.userQuery = "";
      this.assistantResponse = "";


      this.updateDom(300);
    }
  },


  // ==========================================================
  // YOUTUBE FULLSCREEN REAL
  // ==========================================================

  createYouTubeFullscreen: function () {

    console.log(
      "[MMM-TuAsistente] Creando fullscreen REAL"
    );


    // Eliminar cualquier fullscreen anterior

    this.removeYouTubeFullscreen();


    const overlay =
      document.createElement("div");


    overlay.id =
      "tu-asistente-youtube-fullscreen";


    Object.assign(
      overlay.style,
      {
        position: "fixed",
        top: "0",
        left: "0",
        width: "100vw",
        height: "100vh",
        margin: "0",
        padding: "0",
        background: "#000",
        zIndex: "2147483647",
        display: "block",
        overflow: "hidden"
      }
    );


    const iframe =
      document.createElement("iframe");


    iframe.className =
      "youtube-iframe";


    Object.assign(
      iframe.style,
      {
        position: "absolute",
        top: "0",
        left: "0",
        width: "100vw",
        height: "100vh",
        margin: "0",
        padding: "0",
        border: "0",
        display: "block"
      }
    );


    iframe.src =
      "https://www.youtube.com/embed/" +
      this.youtubeVideoId +
      "?autoplay=1" +
      "&controls=1" +
      "&modestbranding=1" +
      "&rel=0" +
      "&enablejsapi=1" +
      "&playsinline=1" +
      "&origin=" +
      encodeURIComponent(
        window.location.origin
      );


    iframe.allow =
      "accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; fullscreen";


    iframe.allowFullscreen =
      true;


    iframe.referrerPolicy =
      "strict-origin-when-cross-origin";


    overlay.appendChild(
      iframe
    );


    document.body.appendChild(
      overlay
    );


    this.youtubeFullscreenElement =
      overlay;


    this.youtubeFullscreenIframe =
      iframe;


    console.log(
      "[MMM-TuAsistente] Fullscreen añadido directamente a document.body"
    );
  },


  // ==========================================================
  // ELIMINAR YOUTUBE FULLSCREEN
  // ==========================================================

  removeYouTubeFullscreen: function () {

    const overlay =
      document.getElementById(
        "tu-asistente-youtube-fullscreen"
      );


    if (overlay) {

      overlay.remove();
    }


    this.youtubeFullscreenElement =
      null;


    this.youtubeFullscreenIframe =
      null;
  },


  // ==========================================================
  // YOUTUBE PLAYER
  // ==========================================================

  initYouTubePlayer: function () {

    const iframe =
      document.querySelector(
        ".youtube-iframe"
      );


    if (
      !iframe ||
      !this.youtubeApiReady
    ) {

      return;
    }


    this.youtubePlayer =
      new YT.Player(
        iframe,
        {

          events: {

            onStateChange:
              (event) => {

              // 0 = vídeo terminado

              if (
                event.data ===
                YT.PlayerState.ENDED
              ) {

                this.youtubeVideoId =
                  null;

                this.youtubePlayer =
                  null;

                this.currentState =
                  "hidden";

                this.userQuery = "";
                this.assistantResponse = "";

                this.updateDom(300);
              }
            }
          }
        }
      );
  },


  // ==========================================================
  // DOM
  // ==========================================================

  getDom: function () {

      // ========================================================
      // LIMPIAR INDICADOR DE VOLUMEN ANTERIOR
      // ========================================================

      const oldVolumeIndicator =
        document.getElementById(
          "mmm-tu-asistente-volume"
        );

      if (oldVolumeIndicator) {
        oldVolumeIndicator.remove();
      }

    const wrapper =
      document.createElement("div");


    wrapper.className =
      `asistente-container ${this.currentState}` +
      (
        this.currentState === "video" &&
        this.youtubeFullscreen
          ? " youtube-fullscreen"
          : ""
      );


    // ========================================================
    // INDICADOR DE VOLUMEN
    // ========================================================

    const showVolume =
      this.volumeStatus ||
      this.volumeMuted;


    if (showVolume) {

      // ------------------------------------------------------
      // IMPORTANTE
      //
      // Si el asistente está hidden, el indicador de volumen
      // debe seguir siendo visible.
      // ------------------------------------------------------

      wrapper.classList.remove(
        "hidden"
      );


      const volumeIndicator =
        document.createElement("div");


      volumeIndicator.className =
        "tu-asistente-volume";

      volumeIndicator.id =
        "mmm-tu-asistente-volume";


      // ------------------------------------------------------
      // CÍRCULO
      // ------------------------------------------------------

      const volumeCircle =
        document.createElement("div");


      volumeCircle.className =
        "volume-circle";


      // ------------------------------------------------------
      // PORCENTAJE
      // ------------------------------------------------------

      const percentage =
        Math.max(
          0,
          Math.min(
            100,
            Number(this.volumeLevel) || 0
          )
        );


      // ------------------------------------------------------
      // ARCO
      // ------------------------------------------------------

      volumeCircle.style.setProperty(
        "--volume-angle",
        `${percentage * 3.6}deg`
      );


      // ------------------------------------------------------
      // MUTE
      // ------------------------------------------------------

      if (this.volumeMuted) {

        volumeCircle.classList.add(
          "muted"
        );
      }


      // ------------------------------------------------------
      // ICONO
      // ------------------------------------------------------

      const icon =
        document.createElement("div");


      icon.className =
        "volume-icon";


      icon.textContent =
        this.volumeMuted
          ? "🔇"
          : "🔊";


      // ------------------------------------------------------
      // PORCENTAJE
      // ------------------------------------------------------

      const percentageEl =
        document.createElement("div");


      percentageEl.className =
        "volume-percentage";


      percentageEl.textContent =
        `${percentage}%`;


      // ------------------------------------------------------
      // TEXTO
      // ------------------------------------------------------

      const label =
        document.createElement("div");


      label.className =
        "volume-label";


      label.textContent =
        this.volumeMuted
          ? "SILENCIADO"
          : "VOLUMEN";


      // ------------------------------------------------------
      // CONSTRUIR
      // ------------------------------------------------------

      volumeCircle.appendChild(
        icon
      );

      // En mute solo mostramos el icono.
      // No mostrar porcentaje ni texto.
      if (!this.volumeMuted) {

        volumeCircle.appendChild(
          percentageEl
        );

        volumeCircle.appendChild(
          label
        );
      }

      volumeIndicator.appendChild(
        volumeCircle
      );

      // El indicador de volumen es independiente del asistente.
      // Se coloca directamente en el DOM del m\xF3dulo.
      volumeIndicator.style.position = "fixed";
      volumeIndicator.style.right = "5px";
      volumeIndicator.style.bottom = "5px";
      volumeIndicator.style.top = "auto";
      volumeIndicator.style.left = "auto";

      document.body.appendChild(
        volumeIndicator
      );
    }


    // ========================================================
    // SPOTIFY / LIBRESPOT
    // ========================================================

    if (
      this.spotifyEvent &&
      this.spotifyEvent.event === "track_changed"
    ) {

      const spotifyCard =
        document.createElement("div");

      spotifyCard.className =
        "tu-asistente-spotify";

      spotifyCard.id =
        "mmm-tu-asistente-spotify";


      // ------------------------------------------------------
      // ICONO
      // ------------------------------------------------------

      const spotifyIcon =
        document.createElement("div");

      spotifyIcon.className =
        "spotify-icon";

      spotifyIcon.textContent =
        "♫";


      // ------------------------------------------------------
      // INFORMACIÓN
      // ------------------------------------------------------

      const spotifyInfo =
        document.createElement("div");

      spotifyInfo.className =
        "spotify-info";


      // ------------------------------------------------------
      // CANCIÓN
      // ------------------------------------------------------

      const spotifyTitle =
        document.createElement("div");

      spotifyTitle.className =
        "spotify-title";

      spotifyTitle.textContent =
        this.spotifyEvent.name ||
        "Sin título";


      // ------------------------------------------------------
      // ARTISTA
      // ------------------------------------------------------

      const spotifyArtist =
        document.createElement("div");

      spotifyArtist.className =
        "spotify-artist";

      spotifyArtist.textContent =
        this.spotifyEvent.artists ||
        "Artista desconocido";


      // ------------------------------------------------------
      // ÁLBUM
      // ------------------------------------------------------

      const spotifyAlbum =
        document.createElement("div");

      spotifyAlbum.className =
        "spotify-album";

      spotifyAlbum.textContent =
        this.spotifyEvent.album ||
        "";


      // ------------------------------------------------------
      // CONSTRUIR
      // ------------------------------------------------------

      spotifyInfo.appendChild(
        spotifyTitle
      );

      spotifyInfo.appendChild(
        spotifyArtist
      );

      if (
        this.spotifyEvent.album
      ) {

        spotifyInfo.appendChild(
          spotifyAlbum
        );
      }

      spotifyCard.appendChild(
        spotifyIcon
      );

      spotifyCard.appendChild(
        spotifyInfo
      );


      // ------------------------------------------------------
      // POSICIÓN
      // ESQUINA INFERIOR IZQUIERDA
      // ------------------------------------------------------

      spotifyCard.style.position =
        "fixed";

      spotifyCard.style.left =
        "20px";

      spotifyCard.style.bottom =
        "20px";

      spotifyCard.style.right =
        "auto";

      spotifyCard.style.top =
        "auto";

      spotifyCard.style.zIndex =
        "9999";


      // ------------------------------------------------------
      // ESTILO
      // ------------------------------------------------------

      spotifyCard.style.display =
        "flex";

      spotifyCard.style.alignItems =
        "center";

      spotifyCard.style.gap =
        "12px";

      spotifyCard.style.padding =
        "12px 18px";

      spotifyCard.style.borderRadius =
        "14px";

      spotifyCard.style.background =
        "rgba(0, 0, 0, 0.82)";

      spotifyCard.style.boxShadow =
        "0 4px 20px rgba(0,0,0,0.45)";

      spotifyCard.style.fontFamily =
        "Arial, sans-serif";

      spotifyCard.style.maxWidth =
        "380px";


      // ------------------------------------------------------
      // ICONO
      // ------------------------------------------------------

      spotifyIcon.style.fontSize =
        "34px";

      spotifyIcon.style.fontWeight =
        "bold";

      spotifyIcon.style.lineHeight =
        "1";

      spotifyIcon.style.color =
        "#1DB954";


      // ------------------------------------------------------
      // INFORMACIÓN
      // ------------------------------------------------------

      spotifyInfo.style.display =
        "flex";

      spotifyInfo.style.flexDirection =
        "column";

      spotifyInfo.style.minWidth =
        "0";


      // ------------------------------------------------------
      // TÍTULO
      // ------------------------------------------------------

      spotifyTitle.style.fontSize =
        "20px";

      spotifyTitle.style.fontWeight =
        "bold";

      spotifyTitle.style.color =
        "#ffffff";

      spotifyTitle.style.whiteSpace =
        "nowrap";

      spotifyTitle.style.overflow =
        "hidden";

      spotifyTitle.style.textOverflow =
        "ellipsis";


      // ------------------------------------------------------
      // ARTISTA
      // ------------------------------------------------------

      spotifyArtist.style.fontSize =
        "16px";

      spotifyArtist.style.color =
        "#dddddd";

      spotifyArtist.style.marginTop =
        "3px";


      // ------------------------------------------------------
      // ÁLBUM
      // ------------------------------------------------------

      spotifyAlbum.style.fontSize =
        "13px";

      spotifyAlbum.style.color =
        "#999999";

      spotifyAlbum.style.marginTop =
        "3px";


      document.body.appendChild(
        spotifyCard
      );
    }


    // ========================================================
    // IMAGEN DE BÚSQUEDA
    // ========================================================

    if (
      this.currentState === "image" &&
      this.imageUrl
    ) {

      const imageContainer =
        document.createElement("div");


      imageContainer.className =
        "assistant-image-container";


      const image =
        document.createElement("img");


      image.className =
        "assistant-image";


      image.src =
        this.imageUrl;


      image.alt =
        this.imageQuery ||
        "Imagen";


      image.onload = () => {

        console.log(
          "[MMM-TuAsistente] Imagen cargada correctamente."
        );
      };


      image.onerror = () => {

        console.error(
          "[MMM-TuAsistente] Error cargando imagen:",
          this.imageUrl
        );
      };


      imageContainer.appendChild(
        image
      );


      wrapper.appendChild(
        imageContainer
      );


      // IMPORTANTE:
      // No seguimos procesando el contenido normal.
      // La imagen tiene su propio ciclo de vida.

      return wrapper;
    }


    // ========================================================
    // YOUTUBE
    // ========================================================

    if (
      this.currentState === "video"
    ) {

      if (this.youtubeVideoId) {

        const ytContainer =
          document.createElement("div");


        ytContainer.className =
          "youtube-container";


        const iframe =
          document.createElement("iframe");


        iframe.className =
          "youtube-iframe";


        iframe.src =
          `https://www.youtube.com/embed/${this.youtubeVideoId}` +
          `?autoplay=1` +
          `&controls=1` +
          `&modestbranding=1` +
          `&rel=0` +
          `&enablejsapi=1` +
          `&origin=${encodeURIComponent(
            window.location.origin
          )}`;


        iframe.allow =
          "accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture";


        iframe.allowFullscreen =
          true;


        iframe.referrerPolicy =
          "strict-origin-when-cross-origin";


        ytContainer.appendChild(
          iframe
        );


        wrapper.appendChild(
          ytContainer
        );
      }


      return wrapper;
    }


    // ========================================================
    // IMAGEN DEL ASISTENTE
    // ========================================================

    // ========================================================
    // IMAGEN DEL ASISTENTE
    // ========================================================

    if (this.currentState !== "hidden") {

      const iconContainer =
        document.createElement("div");

      iconContainer.className =
        `icon-container ${this.currentState}`;

      const img =
        document.createElement("img");

      img.src =
        this.file(
          this.getImageForState(
            this.currentState
          )
        );

      img.className =
        "state-img";

      iconContainer.appendChild(
        img
      );

      wrapper.appendChild(
        iconContainer
      );
    }


    // ========================================================
    // ESTADO OCULTO
    // ========================================================

    if (
      this.currentState === "hidden"
    ) {

      return wrapper;
    }



    // ========================================================
    // CONSULTA DEL USUARIO
    // ========================================================

    if (this.userQuery) {

      const queryEl =
        document.createElement("div");


      queryEl.className =
        "user-query";


      queryEl.textContent =
        `"${this.userQuery}"`;


      wrapper.appendChild(
        queryEl
      );
    }


    // ========================================================
    // RESPUESTA DE JARVIS
    // ========================================================

    if (
      this.assistantResponse &&
      this.currentState !== "recording"
    ) {

      const responseEl =
        document.createElement("div");


      responseEl.className =
        "assistant-response";


      responseEl.textContent =
        this.assistantResponse;


      wrapper.appendChild(
        responseEl
      );
    }


    return wrapper;
  }

});

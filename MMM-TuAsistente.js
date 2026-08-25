Module.register("MMM-TuAsistente", {
  defaults: {
    model: "qwen2.5:1.5b",
    hideDelay: 5000
  },

  getStyles: function () {
    return ["MMM-TuAsistente.css"];
  },

  start: function () {
    this.userQuery = "";
    this.assistantResponse = "";
    this.currentState = "hidden";
    this.youtubeVideoId = null;
    this.imageUrl = null;
    this.imageQuery = "";
    this.hideTimer = null;

    this.sendSocketNotification("INIT_CONFIG", this.config);
this.youtubePlayer = null;
this.youtubeApiReady = false;

if (!window.YT) {
  const tag = document.createElement("script");
  tag.src = "https://www.youtube.com/iframe_api";
  document.head.appendChild(tag);
}

window.onYouTubeIframeAPIReady = () => {
  this.youtubeApiReady = true;
};
  },

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

  socketNotificationReceived: function (notification, payload) {

    if (notification === "STATUS") {

      if (payload.includes("Grabando")) {

        if (this.hideTimer) {
          clearTimeout(this.hideTimer);
        }

        this.currentState = "recording";
        this.assistantResponse = "";
        this.userQuery = "";
      }

      else if (payload.includes("Pensando")) {

        this.currentState = "thinking";
      }

      else if (payload === "CANCELLED" || payload === "ERROR") {

        if (this.hideTimer) {
          clearTimeout(this.hideTimer);
        }

        if (this.currentState !== "video") {
          this.currentState = "hidden";
        }

        this.userQuery = "";
        this.assistantResponse = "";
      }

      this.updateDom(200);
    }


    else if (notification === "USER_QUERY") {

      this.userQuery = payload;
      this.updateDom(200);
    }


    else if (notification === "ASSISTANT_RESPONSE") {

      this.assistantResponse = payload;

      if (
        this.currentState !== "video" &&
        this.currentState !== "image"
      ) {
        this.currentState = "speaking";
      }

      this.updateDom(200);

      if (
        this.currentState !== "video" &&
        this.currentState !== "image"
      ) {

        if (this.hideTimer) {
          clearTimeout(this.hideTimer);
        }

        this.hideTimer = setTimeout(() => {

          this.currentState = "hidden";
          this.userQuery = "";
          this.assistantResponse = "";

          this.updateDom(500);

        }, this.config.hideDelay);
      }
    }


    else if (notification === "SHOW_IMAGE") {

      if (this.hideTimer) {
        clearTimeout(this.hideTimer);
      }

      this.imageUrl = payload.url;
      this.imageQuery = payload.query || "";

      this.currentState = "image";

      this.userQuery = "";
      this.assistantResponse = "";

      console.log(
        "[MMM-TuAsistente] Mostrando imagen:",
        this.imageUrl
      );

      this.updateDom(300);

      this.hideTimer = setTimeout(() => {

        this.imageUrl = null;
        this.imageQuery = "";

        this.currentState = "hidden";

        this.updateDom(300);

      }, this.config.hideDelay);

    }


    else if (notification === "PLAY_YOUTUBE") {

      if (this.hideTimer) {
        clearTimeout(this.hideTimer);
      }

      this.youtubeVideoId = payload.videoId;
      this.currentState = "video";

      this.userQuery = "";
      this.assistantResponse = "";

      this.updateDom(300);
setTimeout(() => {
  this.initYouTubePlayer();
}, 500);
    }


    else if (notification === "STOP_YOUTUBE") {

      this.youtubeVideoId = null;

      this.currentState = "hidden";
      this.userQuery = "";
      this.assistantResponse = "";

      this.updateDom(300);
    }
  },

initYouTubePlayer: function () {

  const iframe = document.querySelector(".youtube-iframe");

  if (!iframe || !this.youtubeApiReady) {
    return;
  }

  this.youtubePlayer = new YT.Player(iframe, {

    events: {
      onStateChange: (event) => {

        // 0 = vídeo terminado
        if (event.data === YT.PlayerState.ENDED) {

          this.youtubeVideoId = null;
          this.youtubePlayer = null;

          this.currentState = "hidden";
          this.userQuery = "";
          this.assistantResponse = "";

          this.updateDom(300);
        }
      }
    }
  });
},
  getDom: function () {

    const wrapper = document.createElement("div");

    wrapper.className =
      `asistente-container ${this.currentState}`;


    /*
     * YOUTUBE
     *
     * Cuando estamos en vídeo:
     * - No mostramos imagen
     * - No mostramos pregunta
     * - No mostramos respuesta
     * - Solo mostramos YouTube
     */

    /*
     * IMAGEN
     *
     * Mostramos directamente la imagen encontrada.
     */

    if (this.currentState === "image") {

      if (this.imageUrl) {

        const imageContainer =
          document.createElement("div");

        imageContainer.className =
          "assistant-image-container";

        const image =
          document.createElement("img");

        image.className =
          "assistant-image";

        image.src = this.imageUrl;

        image.alt =
          this.imageQuery || "Imagen";

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

        imageContainer.appendChild(image);
        wrapper.appendChild(imageContainer);
      }

      return wrapper;
    }


    if (this.currentState === "video") {

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
          `&origin=${encodeURIComponent(window.location.origin)}`;


        iframe.allow =
          "accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture";


        iframe.allowFullscreen = true;

        iframe.referrerPolicy =
          "strict-origin-when-cross-origin";


        ytContainer.appendChild(iframe);

        wrapper.appendChild(ytContainer);
      }

      return wrapper;
    }


    /*
     * IMAGEN DEL ASISTENTE
     *
     * No se muestra cuando estamos en YouTube.
     */

    const iconContainer =
      document.createElement("div");

    iconContainer.className =
      `icon-container ${this.currentState}`;


    const img =
      document.createElement("img");

    img.src =
      this.file(
        this.getImageForState(this.currentState)
      );

    img.className =
      "state-img";


    iconContainer.appendChild(img);

    wrapper.appendChild(iconContainer);


    /*
     * ESTADO OCULTO
     */

    if (this.currentState === "hidden") {
      return wrapper;
    }


    /*
     * CONSULTA DEL USUARIO
     */

    if (this.userQuery) {

      const queryEl =
        document.createElement("div");

      queryEl.className =
        "user-query";

      queryEl.textContent =
        `"${this.userQuery}"`;

      wrapper.appendChild(queryEl);
    }


    /*
     * RESPUESTA DE JARVIS
     */

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

      wrapper.appendChild(responseEl);
    }


    return wrapper;
  }
});

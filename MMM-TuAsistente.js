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
    this.currentState = "hidden"; // hidden, recording, thinking, speaking
    this.hideTimer = null;

    this.sendSocketNotification("INIT_CONFIG", this.config);
  },

  getImageForState: function (state) {
    switch (state) {
      case "recording":
        return "images/recording.jpg";
      case "thinking":
      case "speaking":
      default:
        return "images/thinking.png";
    }
  },

  socketNotificationReceived: function (notification, payload) {
    if (notification === "STATUS") {
      if (payload.includes("Grabando")) {
        if (this.hideTimer) clearTimeout(this.hideTimer);
        this.currentState = "recording";
        this.assistantResponse = "";
        this.userQuery = "";
      } else if (payload.includes("Pensando")) {
        this.currentState = "thinking";
      } else if (payload === "CANCELLED" || payload === "ERROR") {
        if (this.hideTimer) clearTimeout(this.hideTimer);
        this.currentState = "hidden";
        this.userQuery = "";
        this.assistantResponse = "";
      }
      this.updateDom(200);

    } else if (notification === "USER_QUERY") {
      this.userQuery = payload;
      this.updateDom(200);

    } else if (notification === "ASSISTANT_RESPONSE") {
      this.assistantResponse = payload;
      this.currentState = "speaking";
      this.updateDom(200);

      if (this.hideTimer) clearTimeout(this.hideTimer);
      this.hideTimer = setTimeout(() => {
        this.currentState = "hidden";
        this.userQuery = "";
        this.assistantResponse = "";
        this.updateDom(500);
      }, this.config.hideDelay);
    }
  },

  getDom: function () {
    const wrapper = document.createElement("div");
    wrapper.className = `asistente-container ${this.currentState}`;

    if (this.currentState === "hidden") {
      return wrapper;
    }

    const iconContainer = document.createElement("div");
    iconContainer.className = `icon-container ${this.currentState}`;

    const img = document.createElement("img");
    img.src = this.file(this.getImageForState(this.currentState));
    img.className = "state-img";
    iconContainer.appendChild(img);

    wrapper.appendChild(iconContainer);

    if (this.userQuery) {
      const queryEl = document.createElement("div");
      queryEl.className = "user-query";
      queryEl.innerHTML = `"${this.userQuery}"`;
      wrapper.appendChild(queryEl);
    }

    if (this.assistantResponse && this.currentState !== "recording") {
      const responseEl = document.createElement("div");
      responseEl.className = "assistant-response";
      responseEl.innerHTML = this.assistantResponse;
      wrapper.appendChild(responseEl);
    }

    return wrapper;
  }
});

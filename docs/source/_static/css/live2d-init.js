(function () {
  const holderId = "live2d-holder";
  const triggerId = "live2d-trigger";
  let cancelled = false;
  let started = false;
  const isMobile = () => {
    const ua = navigator.userAgent || "";
    const viaUA = /mobile|android|iphone|ipad|ipod|phone/i.test(ua);
    const smallViewport = Math.min(window.innerWidth, window.innerHeight) < 780;
    return viaUA || smallViewport;
  };
  const webglSupported = () => {
    try {
      const canvas = document.createElement("canvas");
      return !!(
        window.WebGLRenderingContext &&
        (canvas.getContext("webgl") || canvas.getContext("experimental-webgl"))
      );
    } catch (e) {
      return false;
    }
  };

  const textMap = {
    ready: "妙妙屋的奇妙咒语",
    loading: "召唤中...",
    done: "阿尼亚就位",
    error: "召唤失败，点我重试",
  };

  const getHolder = () => document.getElementById(holderId);
  const getTrigger = () => document.getElementById(triggerId);

  const markCancelled = () => {
    // 页面切走或标签页被隐藏时，不再继续加载，避免导航过程卡顿
    if (document.visibilityState === "hidden") {
      cancelled = true;
    }
  };

  const whenIdle = () =>
    new Promise((resolve) => {
      if ("requestIdleCallback" in window) {
        requestIdleCallback(resolve, { timeout: 1200 });
      } else {
        setTimeout(resolve, 300);
      }
    });

  const loadScript = (src) =>
    new Promise((resolve, reject) => {
      const el = document.createElement("script");
      el.src = src;
      el.async = false; // 保证顺序加载
      el.onload = () => resolve();
      el.onerror = (err) => reject(err);
      document.head.appendChild(el);
    });

  const updateTriggerState = (state) => {
    const trigger = getTrigger();
    if (!trigger) return;

    trigger.dataset.state = state;

    const text = textMap[state] || textMap.ready;
    const textNode = trigger.querySelector(".live2d-trigger-text");
    if (textNode) textNode.textContent = text;

    trigger.disabled = state === "loading" || state === "done";
  };

  const cleanupListeners = () => {
    document.removeEventListener("visibilitychange", markCancelled);
  };

  const hideTriggerSoon = () => {
    const trigger = getTrigger();
    if (!trigger) return;
    setTimeout(() => {
      const again = getTrigger();
      if (again && again.dataset.state === "done") {
        again.style.display = "none";
      }
    }, 3000);
  };
  const showFallback = (reason) => {
    const holder = getHolder();
    if (!holder) return;
    holder.classList.add("live2d-fallback");
    holder.dataset.msg = reason || "阿尼亚今天休息~";
    updateTriggerState("done");
    hideTriggerSoon();
  };

  const buildStaticUrl = (relativePath) => {
    const options = document.getElementById("documentation_options");
    const urlRoot = options?.dataset?.url_root || "./";
    const prefix = urlRoot.endsWith("/") ? urlRoot : `${urlRoot}/`;
    return `${prefix}${relativePath.replace(/^\//, "")}`;
  };

  const fitModel = (app, model) => {
    const holder = getHolder();
    if (!holder || !model) return;

    const { width, height } = holder.getBoundingClientRect();
    app.renderer.resize(width, height);

    const baseW = model.__baseWidth || model.width;
    const baseH = model.__baseHeight || model.height;
    const scale = Math.min(width / baseW, height / baseH) * 1.2;

    model.scale.set(scale);
    model.position.set(width / 2, height * 0.98);
  };

  const init = async () => {
    const holder = getHolder();
    if (!holder) return false;

    if (!webglSupported()) {
      showFallback("设备不支持 WebGL，显示占位图");
      return false;
    }

    document.addEventListener("visibilitychange", markCancelled);

    await whenIdle(); // 把加载延后到空闲/几百毫秒后，减少首屏阻塞
    if (cancelled || !getHolder()) {
      cleanupListeners();
      return false;
    }

    try {
      await loadScript(buildStaticUrl("_static/css/pixi.min.js"));
      await loadScript(buildStaticUrl("_static/css/live2dcubismcore.min.js"));
      await loadScript(buildStaticUrl("_static/css/cubism4.min.js"));
    } catch (err) {
      console.warn("[Live2D] 依赖加载失败：", err);
      cleanupListeners();
      return false;
    }

    if (cancelled || !getHolder()) {
      cleanupListeners();
      return false;
    }

    if (!window.PIXI || !PIXI.live2d?.Live2DModel) {
      console.warn("[Live2D] PIXI 或 live2d 依赖未就绪");
      cleanupListeners();
      return false;
    }

    const app = new PIXI.Application({
      backgroundAlpha: 0,
      resizeTo: holder,
      antialias: true,
      powerPreference: "low-power",
    });
    app.renderer.view.style.backgroundColor = "transparent";
    app.renderer.clear();
    if (app.renderer.type === PIXI.RENDERER_TYPE.WEBGL && !app.renderer.gl) {
      app.destroy(true);
      cleanupListeners();
      showFallback("设备 WebGL 不可用，显示占位图");
      return false;
    }
    holder.appendChild(app.view);

    const modelUrl = buildStaticUrl("_static/live2d/ANIYA-walk/ANIYA.model3.json");

    try {
      const model = await PIXI.live2d.Live2DModel.from(modelUrl);
      if (cancelled || !getHolder()) {
        model.destroy(true);
        app.destroy(true);
        cleanupListeners();
        return false;
      }
      // 记录原始尺寸，便于缩放
      model.__baseWidth = model.width;
      model.__baseHeight = model.height;
      model.anchor.set(0.5, 0.8);

      app.stage.addChild(model);
      fitModel(app, model);
      window.addEventListener("resize", () => fitModel(app, model));
    } catch (err) {
      console.warn("[Live2D] 模型加载失败：", err);
      app.destroy(true);
      cleanupListeners();
      showFallback("移动端渲染异常，显示占位图");
      return false;
    }

    cleanupListeners();
    return true;
  };

  const start = async () => {
    if (started) return;
    started = true;
    cancelled = false;

    const holder = getHolder();
    if (holder) {
      holder.classList.remove("live2d-fallback");
      holder.removeAttribute("data-msg");
    }

    updateTriggerState("loading");
    const ok = await init();

    if (ok) {
      updateTriggerState("done");
      hideTriggerSoon();
    } else {
      started = false; // 允许重试
      cancelled = false;
      updateTriggerState("error");
    }
  };

  const setup = () => {
    if (!getHolder()) return; // 非主页无需处理

    const trigger = getTrigger();
    if (trigger) {
      updateTriggerState("ready");
      trigger.addEventListener("click", start);
    } else {
      // 没有按钮时保持原来的自动加载行为
      start();
    }
  };

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", setup);
  } else {
    setup();
  }
})();

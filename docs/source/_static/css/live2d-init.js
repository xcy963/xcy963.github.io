(function () {
  const holderId = "live2d-holder";

  const getHolder = () => document.getElementById(holderId);

  const loadScript = (src) =>
    new Promise((resolve, reject) => {
      const el = document.createElement("script");
      el.src = src;
      el.async = false; // 保证顺序加载
      el.onload = () => resolve();
      el.onerror = (err) => reject(err);
      document.head.appendChild(el);
    });

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
    if (!holder) return;

    try {
      await loadScript(buildStaticUrl("_static/css/pixi.min.js"));
      await loadScript(buildStaticUrl("_static/css/live2dcubismcore.min.js"));
      await loadScript(buildStaticUrl("_static/css/cubism4.min.js"));
    } catch (err) {
      console.warn("[Live2D] 依赖加载失败：", err);
      return;
    }

    if (!window.PIXI || !PIXI.live2d?.Live2DModel) {
      console.warn("[Live2D] PIXI 或 live2d 依赖未就绪");
      return;
    }

    const app = new PIXI.Application({
      backgroundAlpha: 0,
      resizeTo: holder,
      antialias: true,
    });
    holder.appendChild(app.view);

    const modelUrl = buildStaticUrl("_static/live2d/ANIYA-walk/ANIYA.model3.json");

    try {
      const model = await PIXI.live2d.Live2DModel.from(modelUrl);
      // 记录原始尺寸，便于缩放
      model.__baseWidth = model.width;
      model.__baseHeight = model.height;
      model.anchor.set(0.5, 0.8);

      app.stage.addChild(model);
      fitModel(app, model);
      window.addEventListener("resize", () => fitModel(app, model));
    } catch (err) {
      console.warn("[Live2D] 模型加载失败：", err);
    }
  };

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();

import {
  AbsoluteFill,
  Img,
  Sequence,
  interpolate,
  spring,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";

// Usput.ba brand: dark navy, site-blue headlines, yellow accents.
const BG = "#0a0f1e";
const BLUE = "#3b82f6";
const BLUE_LIGHT = "#60a5fa";
const YELLOW = "#facc15";
const RED = "#ef4444";
const FONT =
  "'Inter', 'Segoe UI', 'Helvetica Neue', Helvetica, Arial, sans-serif";

// Screenshots are 1513x784, rendered as objectFit: cover into 1920x1080.
const IMG_W = 1513;
const IMG_H = 784;
const SCALE = 1080 / IMG_H;
const CROP_X = (IMG_W * SCALE - 1920) / 2;
const toScreen = (x: number, y: number) => ({
  x: x * SCALE - CROP_X,
  y: y * SCALE,
});

const Fade: React.FC<{ d?: number }> = ({ d = 12 }) => {
  const frame = useCurrentFrame();
  const { durationInFrames } = useVideoConfig();
  const opacity = interpolate(
    frame,
    [0, d, durationInFrames - d, durationInFrames],
    [1, 0, 0, 1],
    { extrapolateLeft: "clamp", extrapolateRight: "clamp" }
  );
  return <AbsoluteFill style={{ backgroundColor: BG, opacity, pointerEvents: "none" }} />;
};

const Shot: React.FC<{ src: string; zoomFrom?: number; zoomTo?: number }> = ({
  src,
  zoomFrom = 1.0,
  zoomTo = 1.06,
}) => {
  const frame = useCurrentFrame();
  const { durationInFrames } = useVideoConfig();
  const scale = interpolate(frame, [0, durationInFrames], [zoomFrom, zoomTo]);
  return (
    <AbsoluteFill style={{ backgroundColor: BG }}>
      <Img
        src={staticFile(src)}
        style={{
          width: "100%",
          height: "100%",
          objectFit: "cover",
          objectPosition: "top center",
          transform: `scale(${scale})`,
        }}
      />
    </AbsoluteFill>
  );
};

type Waypoint = { frame: number; x: number; y: number; click?: boolean };

const Cursor: React.FC<{ path: Waypoint[] }> = ({ path }) => {
  const frame = useCurrentFrame();
  let x = path[0].x;
  let y = path[0].y;
  for (let i = 0; i < path.length - 1; i++) {
    const a = path[i];
    const b = path[i + 1];
    if (frame >= a.frame) {
      const t = interpolate(frame, [a.frame, b.frame], [0, 1], {
        extrapolateLeft: "clamp",
        extrapolateRight: "clamp",
      });
      const ease = t * t * (3 - 2 * t);
      x = a.x + (b.x - a.x) * ease;
      y = a.y + (b.y - a.y) * ease;
    }
  }
  const s = toScreen(x, y);
  const clicks = path.filter((p) => p.click);
  return (
    <>
      {clicks.map((c, i) => {
        const cs = toScreen(c.x, c.y);
        const t = interpolate(c.frame + 3 <= frame ? frame : -1, [c.frame + 3, c.frame + 22], [0, 1], {
          extrapolateLeft: "clamp",
          extrapolateRight: "clamp",
        });
        if (frame < c.frame + 3 || t >= 1) return null;
        return (
          <div
            key={i}
            style={{
              position: "absolute",
              left: cs.x - 45 * t,
              top: cs.y - 45 * t,
              width: 90 * t,
              height: 90 * t,
              borderRadius: "50%",
              border: `5px solid ${YELLOW}`,
              opacity: 1 - t,
            }}
          />
        );
      })}
      <svg
        width="44"
        height="44"
        viewBox="0 0 24 24"
        style={{
          position: "absolute",
          left: s.x,
          top: s.y,
          filter: "drop-shadow(0 3px 6px rgba(0,0,0,0.6))",
        }}
      >
        <path
          d="M5 3l14 8.5-6.1 1.2 3.4 6.3-2.7 1.4-3.3-6.3L5 18.5z"
          fill="white"
          stroke="#0f172a"
          strokeWidth="1.4"
        />
      </svg>
    </>
  );
};

const Caption: React.FC<{ text: string; accent?: string; delay?: number }> = ({
  text,
  accent = YELLOW,
  delay = 6,
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const enter = spring({ frame: frame - delay, fps, config: { damping: 200 } });
  return (
    <div
      style={{
        position: "absolute",
        left: 70,
        bottom: 60,
        maxWidth: 1350,
        display: "flex",
        alignItems: "center",
        gap: 26,
        transform: `translateY(${interpolate(enter, [0, 1], [40, 0])}px)`,
        opacity: enter,
      }}
    >
      <img
        src={staticFile("logo.png")}
        style={{ height: 64, width: "auto" }}
      />
      <div
        style={{
          fontFamily: FONT,
          fontSize: 40,
          fontWeight: 700,
          color: "white",
          backgroundColor: "rgba(10,15,30,0.88)",
          border: `3px solid ${accent}`,
          borderRadius: 18,
          padding: "18px 30px",
          lineHeight: 1.3,
          boxShadow: "0 10px 40px rgba(0,0,0,0.6)",
        }}
      >
        {text}
      </div>
    </div>
  );
};

const DangerBanner: React.FC<{ delay: number }> = ({ delay }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const enter = spring({ frame: frame - delay, fps, config: { damping: 15 } });
  if (frame < delay) return null;
  return (
    <div
      style={{
        position: "absolute",
        top: 120,
        left: "50%",
        transform: `translateX(-50%) scale(${enter})`,
        fontFamily: FONT,
        fontSize: 44,
        fontWeight: 800,
        color: "white",
        backgroundColor: "rgba(127,29,29,0.95)",
        border: `4px solid ${RED}`,
        borderRadius: 20,
        padding: "26px 44px",
        maxWidth: 1500,
        textAlign: "center",
        boxShadow: "0 14px 60px rgba(0,0,0,0.7)",
      }}
    >
      ⚠ OPASNOST: tačka je unutar ili u neposrednoj blizini (do 500 m)
      evidentiranog minski sumnjivog područja
    </div>
  );
};

const Intro: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const enter = spring({ frame, fps, config: { damping: 200 } });
  const badge = spring({ frame: frame - 30, fps, config: { damping: 14 } });
  return (
    <AbsoluteFill
      style={{ backgroundColor: BG, justifyContent: "center", alignItems: "center" }}
    >
      <div style={{ display: "flex", alignItems: "center", gap: 40, opacity: enter }}>
        <img
          src={staticFile("logo.png")}
          style={{
            height: 170,
            width: "auto",
            transform: `scale(${interpolate(enter, [0, 1], [0.7, 1])})`,
          }}
        />
        <div
          style={{
            fontFamily: FONT,
            fontSize: 130,
            fontWeight: 900,
            color: "white",
          }}
        >
          Usput<span style={{ color: BLUE_LIGHT }}>.ba</span>
        </div>
      </div>
      <div
        style={{
          fontFamily: FONT,
          fontSize: 42,
          fontWeight: 600,
          color: "#94a3b8",
          marginTop: 26,
          opacity: interpolate(frame, [15, 40], [0, 1], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          }),
        }}
      >
        Otkrij ljepote Bosne i Hercegovine
      </div>
      <div
        style={{
          fontFamily: FONT,
          fontSize: 38,
          fontWeight: 800,
          color: "#0a0f1e",
          backgroundColor: YELLOW,
          borderRadius: 999,
          padding: "14px 40px",
          marginTop: 60,
          transform: `scale(${badge})`,
        }}
      >
        NOVO · Minska sigurnost
      </div>
    </AbsoluteFill>
  );
};

const Outro: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const enter = spring({ frame, fps, config: { damping: 200 } });
  const line = (delay: number) =>
    interpolate(frame, [delay, delay + 18], [0, 1], {
      extrapolateLeft: "clamp",
      extrapolateRight: "clamp",
    });
  return (
    <AbsoluteFill
      style={{ backgroundColor: BG, justifyContent: "center", alignItems: "center" }}
    >
      <img
        src={staticFile("logo.png")}
        style={{ height: 130, width: "auto", opacity: enter, marginBottom: 40 }}
      />
      <div
        style={{
          fontFamily: FONT,
          fontSize: 80,
          fontWeight: 800,
          color: "white",
          opacity: enter,
        }}
      >
        usput.ba<span style={{ color: BLUE_LIGHT }}>/mine-check</span>
      </div>
      <div
        style={{
          fontFamily: FONT,
          fontSize: 80,
          fontWeight: 800,
          color: "white",
          marginTop: 6,
          opacity: line(14),
        }}
      >
        usput.ba<span style={{ color: YELLOW }}>/minesweeper</span>
      </div>
      <div
        style={{
          fontFamily: FONT,
          fontSize: 30,
          color: "#94a3b8",
          marginTop: 56,
          opacity: line(36),
        }}
      >
        Edukacija, ne navigacija &middot; Jedini mjerodavni izvor: BHMAC (bhmac.org &middot; 033/253-800)
      </div>
    </AbsoluteFill>
  );
};

export const Promo: React.FC = () => {
  return (
    <AbsoluteFill style={{ backgroundColor: BG }}>
      <Sequence durationInFrames={105}>
        <Intro />
        <Fade />
      </Sequence>

      {/* Homepage -> click "Provjera mina" in the nav */}
      <Sequence from={105} durationInFrames={120}>
        <Shot src="home.jpg" />
        <Cursor
          path={[
            { frame: 10, x: 760, y: 400 },
            { frame: 55, x: 809, y: 38, click: true },
            { frame: 120, x: 809, y: 38 },
          ]}
        />
        <Caption text="Sve počinje na početnoj — klik na „Provjera mina“" accent={BLUE} />
        <Fade />
      </Sequence>

      {/* Checker: national red dots */}
      <Sequence from={225} durationInFrames={165}>
        <Shot src="dots.jpg" zoomFrom={1.0} zoomTo={1.08} />
        <Caption
          text="3.700+ evidentiranih minski sumnjivih zona — odmah na karti"
          accent={RED}
        />
        <Fade />
      </Sequence>

      {/* Coordinates check -> danger verdict */}
      <Sequence from={390} durationInFrames={195}>
        <Shot src="coords.jpg" zoomFrom={1.02} zoomTo={1.08} />
        <Cursor
          path={[
            { frame: 8, x: 794, y: 470 },
            { frame: 45, x: 909, y: 393, click: true },
            { frame: 195, x: 909, y: 393 },
          ]}
        />
        <DangerBanner delay={70} />
        <Caption
          text="GPS, koordinate ili dodir na kartu — jasno upozorenje, bez lažne sigurnosti"
          accent={RED}
          delay={90}
        />
        <Fade />
      </Sequence>

      {/* Minesweeper: board on real terrain */}
      <Sequence from={585} durationInFrames={105}>
        <Shot src="board1.jpg" />
        <Cursor
          path={[
            { frame: 8, x: 750, y: 300 },
            { frame: 50, x: 630, y: 740, click: true },
            { frame: 105, x: 630, y: 740 },
          ]}
        />
        <Caption text="Jedan klik dalje: Minolovac — igra na stvarnim kartama" accent={YELLOW} />
        <Fade />
      </Sequence>
      <Sequence from={690} durationInFrames={150}>
        <Shot src="board2.jpg" zoomFrom={1.02} zoomTo={1.1} />
        <Caption
          text="Mine su tamo gdje stvarni podaci kažu — prazna ćelija ≠ siguran teren"
          accent={YELLOW}
        />
        <Fade />
      </Sequence>

      <Sequence from={840} durationInFrames={200}>
        <Outro />
        <Fade />
      </Sequence>
    </AbsoluteFill>
  );
};

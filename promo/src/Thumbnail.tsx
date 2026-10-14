import { AbsoluteFill, Img, staticFile } from "remotion";

const BG = "#0a0f1e";
const BLUE_LIGHT = "#60a5fa";
const YELLOW = "#facc15";
const FONT =
  "'Inter', 'Segoe UI', 'Helvetica Neue', Helvetica, Arial, sans-serif";

export const Thumbnail: React.FC = () => {
  return (
    <AbsoluteFill style={{ backgroundColor: BG }}>
      <Img
        src={staticFile("dots.jpg")}
        style={{
          width: "100%",
          height: "100%",
          objectFit: "cover",
          objectPosition: "top center",
          transform: "translate(360px, -470px) scale(2.2)",
        }}
      />
      <AbsoluteFill
        style={{
          background:
            "linear-gradient(105deg, rgba(10,15,30,0.97) 0%, rgba(10,15,30,0.9) 34%, rgba(10,15,30,0.45) 62%, rgba(10,15,30,0.15) 100%)",
        }}
      />
      <div
        style={{
          position: "absolute",
          left: 90,
          top: 80,
          display: "flex",
          alignItems: "center",
          gap: 28,
        }}
      >
        <img src={staticFile("logo.png")} style={{ height: 96, width: "auto" }} />
        <div style={{ fontFamily: FONT, fontSize: 64, fontWeight: 900, color: "white" }}>
          Usput<span style={{ color: BLUE_LIGHT }}>.ba</span>
        </div>
      </div>
      <div style={{ position: "absolute", left: 90, top: 300, maxWidth: 1050 }}>
        <div
          style={{
            display: "inline-block",
            fontFamily: FONT,
            fontSize: 34,
            fontWeight: 800,
            color: BG,
            backgroundColor: YELLOW,
            borderRadius: 999,
            padding: "10px 32px",
            marginBottom: 34,
          }}
        >
          NOVO
        </div>
        <div
          style={{
            fontFamily: FONT,
            fontSize: 104,
            fontWeight: 900,
            color: "white",
            lineHeight: 1.08,
            textShadow: "0 6px 40px rgba(0,0,0,0.8)",
          }}
        >
          Provjera minskih
          <br />
          područja u BiH
        </div>
        <div
          style={{
            fontFamily: FONT,
            fontSize: 44,
            fontWeight: 600,
            color: "#cbd5e1",
            marginTop: 30,
            textShadow: "0 3px 20px rgba(0,0,0,0.8)",
          }}
        >
          + edukativni Minolovac na stvarnim podacima
        </div>
      </div>
      <div
        style={{
          position: "absolute",
          left: 90,
          bottom: 70,
          fontFamily: FONT,
          fontSize: 40,
          fontWeight: 800,
          color: "white",
          textShadow: "0 3px 20px rgba(0,0,0,0.8)",
        }}
      >
        usput.ba<span style={{ color: BLUE_LIGHT }}>/mine-check</span>
        <span style={{ color: "#64748b" }}> · </span>
        usput.ba<span style={{ color: YELLOW }}>/minesweeper</span>
      </div>
    </AbsoluteFill>
  );
};

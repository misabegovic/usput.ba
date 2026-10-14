import { Composition, Still } from "remotion";
import { Promo } from "./Promo";
import { Thumbnail } from "./Thumbnail";

export const RemotionRoot: React.FC = () => {
  return (
    <>
      <Composition
        id="Promo"
        component={Promo}
        durationInFrames={1040}
        fps={30}
        width={1920}
        height={1080}
      />
      <Still id="Thumb" component={Thumbnail} width={1920} height={1080} />
    </>
  );
};

import React from "react";
import { Composition } from "remotion";
import { GhostiesAnimation } from "./GhostiesAnimation";

export const RemotionRoot: React.FC = () => {
  return (
    <>
      <Composition
        id="GhostiesAnimation"
        component={GhostiesAnimation}
        durationInFrames={156}
        fps={12}
        width={1080}
        height={1080}
      />
    </>
  );
};

import React from "react";
import { Rect } from "../data/ghosts";

interface GhostProps {
  color: string;
  rects: Rect[];
  scale?: number;
}

export const Ghost: React.FC<GhostProps> = ({ color, rects, scale = 2 }) => {
  const size = 48 * scale;
  return (
    <svg width={size} height={size} viewBox="0 0 48 48" fill={color}>
      {rects.map((r, i) => (
        <rect key={i} x={r.x} y={r.y} width={r.w} height={r.h} />
      ))}
    </svg>
  );
};

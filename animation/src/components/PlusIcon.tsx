import React from "react";

interface PlusIconProps {
  color?: string;
  scale?: number;
}

// 16-bit pixel plus/cross — same 48x48 grid as the ghosts
const PLUS_RECTS = [
  // Vertical bar
  { x: 20, y: 4, w: 8, h: 8 },
  { x: 20, y: 12, w: 8, h: 8 },
  { x: 20, y: 20, w: 8, h: 8 },
  { x: 20, y: 28, w: 8, h: 8 },
  { x: 20, y: 36, w: 8, h: 8 },
  // Horizontal bar
  { x: 4, y: 20, w: 8, h: 8 },
  { x: 12, y: 20, w: 8, h: 8 },
  { x: 28, y: 20, w: 8, h: 8 },
  { x: 36, y: 20, w: 8, h: 8 },
];

export const PlusIcon: React.FC<PlusIconProps> = ({
  color = "rgba(255,255,255,0.5)",
  scale = 2,
}) => {
  const size = 48 * scale;
  return (
    <svg width={size} height={size} viewBox="0 0 48 48" fill={color}>
      {PLUS_RECTS.map((r, i) => (
        <rect key={i} x={r.x} y={r.y} width={r.w} height={r.h} />
      ))}
    </svg>
  );
};

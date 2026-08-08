export type ConceptStatus = "reinspect" | "repaired" | "locked";

export type VersionStatus =
  | "historical_candidate"
  | "current_candidate"
  | "locked_direction";

export type ConceptVersion = {
  id: string;
  referenceName: string;
  image: string;
  stage: string;
  status: VersionStatus;
  sourcePath: string;
  sourceCommit: string;
  sourceDate: string;
  sha256: string;
  width: number;
  height: number;
};

type CurrentUnitConcept = {
  id: string;
  name: string;
  role: string;
  image: string;
  status: ConceptStatus;
  statusLabel: string;
  sourceLabel: string;
  stage: string;
  sourcePath: string;
  sourceCommit: string;
  sourceDate: string;
  sha256: string;
  width: number;
  height: number;
};

export type UnitConcept = CurrentUnitConcept & {
  currentVersionId: string;
  versions: ConceptVersion[];
};

const currentUnitConcepts: CurrentUnitConcept[] = [
  {
    id: "korath",
    name: "Korath",
    role: "Tank",
    image: "/units/korath.png",
    status: "reinspect",
    statusLabel: "Reinspection pending",
    sourceLabel: "Current Phase II master",
    stage: "Phase II candidate",
    sourcePath:
      "assets/concepts/phase2_calibration/korath/korath_master.png",
    sourceCommit: "4b4f2630232155160e43820aac416158816ff346",
    sourceDate: "July 22, 2026",
    sha256:
      "797fe7361cb6864372eaac3e270cf178b7d15b963725c25259f3c54d88b774a3",
    width: 1024,
    height: 1536,
  },
  {
    id: "veyra",
    name: "Veyra",
    role: "Tank",
    image: "/units/veyra.png",
    status: "repaired",
    statusLabel: "Reapproval pending",
    sourceLabel: "Rebuilt Phase II master",
    stage: "Phase II repaired cut",
    sourcePath: "assets/concepts/phase2_calibration/veyra/veyra_master.png",
    sourceCommit: "9d03d7c9c67a11200aa77a8ad1ea4dc800db679a",
    sourceDate: "July 22, 2026",
    sha256:
      "aabad99083a89af926bcd6ad2ef1a6a6d8b8d7873fa5b4716eb8dee3d827da60",
    width: 1122,
    height: 1402,
  },
  {
    id: "cashmere",
    name: "Cashmere",
    role: "Mage",
    image: "/units/cashmere.png",
    status: "repaired",
    statusLabel: "Reapproval pending",
    sourceLabel: "Rebuilt Phase II master",
    stage: "Phase II repaired cut",
    sourcePath:
      "assets/concepts/phase2_calibration/cashmere/cashmere_master.png",
    sourceCommit: "9d03d7c9c67a11200aa77a8ad1ea4dc800db679a",
    sourceDate: "July 22, 2026",
    sha256:
      "f80ba21bebe17067f880b2e44dc203efc7a6751ba5876ba6477a9b105abcd02a",
    width: 1024,
    height: 1536,
  },
  {
    id: "pilfer",
    name: "Pilfer",
    role: "Assassin",
    image: "/units/pilfer.png",
    status: "reinspect",
    statusLabel: "Reinspection pending",
    sourceLabel: "Current Phase II master",
    stage: "Phase II candidate",
    sourcePath:
      "assets/concepts/phase2_calibration/pilfer/pilfer_master.png",
    sourceCommit: "4b4f2630232155160e43820aac416158816ff346",
    sourceDate: "July 22, 2026",
    sha256:
      "7c2d18304b26f8503d1843b2eead432b9fd162ee46ef0f19490da5c99a4d4b1e",
    width: 1023,
    height: 1537,
  },
  {
    id: "nyxa",
    name: "Nyxa",
    role: "Marksman",
    image: "/units/nyxa.png",
    status: "reinspect",
    statusLabel: "Reinspection pending",
    sourceLabel: "Current Phase II master",
    stage: "Phase II candidate",
    sourcePath: "assets/concepts/phase2_calibration/nyxa/nyxa_master.png",
    sourceCommit: "4b4f2630232155160e43820aac416158816ff346",
    sourceDate: "July 22, 2026",
    sha256:
      "49041b874855da4855450660db68598f149a424a8fab44d40a0fec08d2e676d1",
    width: 1024,
    height: 1536,
  },
  {
    id: "creep",
    name: "Creep",
    role: "Assassin",
    image: "/units/creep.png",
    status: "reinspect",
    statusLabel: "Reinspection pending",
    sourceLabel: "Current Phase II master",
    stage: "Phase II candidate",
    sourcePath: "assets/concepts/phase2_calibration/creep/creep_master.png",
    sourceCommit: "f4dc6671854de5acdb27ef2742008d80bfe610de",
    sourceDate: "July 21, 2026",
    sha256:
      "74914b21f3ce70bf65f323ae4b5315c4f206bb5f0a2386263bb8a1dbfffa3020",
    width: 1536,
    height: 1024,
  },
  {
    id: "knoll",
    name: "Knoll",
    role: "Support",
    image: "/units/knoll.png",
    status: "locked",
    statusLabel: "Direction locked",
    sourceLabel: "Foreclosure Press",
    stage: "Stage III redesign direction",
    sourcePath:
      "assets/concepts/phase3_redesign/knoll/knoll_foreclosure_press_selected_direction.png",
    sourceCommit: "a7bacddf1b221015901409ba66870ee6f66b0682",
    sourceDate: "July 23, 2026",
    sha256:
      "25d344c8478f732f4053e8aff13f70aaba3d9060b4b88522d917267effbe1c6e",
    width: 1024,
    height: 1536,
  },
  {
    id: "quillith",
    name: "Quillith",
    role: "Support",
    image: "/units/quillith.png",
    status: "repaired",
    statusLabel: "Reapproval pending",
    sourceLabel: "Rebuilt Phase II master",
    stage: "Phase II repaired cut",
    sourcePath:
      "assets/concepts/phase2_calibration/quillith/quillith_master.png",
    sourceCommit: "9d03d7c9c67a11200aa77a8ad1ea4dc800db679a",
    sourceDate: "July 22, 2026",
    sha256:
      "c0ade3bd7b1e1d61363b629123958f0821308eb4d47eeab1167d8d7a1b9abaa7",
    width: 1023,
    height: 1537,
  },
  {
    id: "kett",
    name: "Kett",
    role: "Brawler",
    image: "/units/kett.png",
    status: "reinspect",
    statusLabel: "Reinspection pending",
    sourceLabel: "Current Phase II master",
    stage: "Phase II candidate",
    sourcePath: "assets/concepts/phase2_calibration/kett/kett_master.png",
    sourceCommit: "4b4f2630232155160e43820aac416158816ff346",
    sourceDate: "July 22, 2026",
    sha256:
      "53e16f7f4ccec0c642264c3ce45f2ca5ac9c4aa64dc16f1d447504001495a426",
    width: 1023,
    height: 1537,
  },
  {
    id: "luna",
    name: "Luna",
    role: "Mage",
    image: "/units/luna.png",
    status: "repaired",
    statusLabel: "Reapproval pending",
    sourceLabel: "Rebuilt Phase II master",
    stage: "Phase II repaired cut",
    sourcePath: "assets/concepts/phase2_calibration/luna/luna_master.png",
    sourceCommit: "9d03d7c9c67a11200aa77a8ad1ea4dc800db679a",
    sourceDate: "July 22, 2026",
    sha256:
      "9436100617222f3f5500715c156793f11b0282cdc95b6b3f767aed2e38b7f836",
    width: 1024,
    height: 1536,
  },
  {
    id: "malachor",
    name: "Malachor",
    role: "Tank",
    image: "/units/malachor.png",
    status: "locked",
    statusLabel: "Direction locked",
    sourceLabel: "Living Siege Cage",
    stage: "Stage III redesign direction",
    sourcePath:
      "assets/concepts/phase3_redesign/malachor/malachor_living_siege_cage_selected_direction.png",
    sourceCommit: "dd546e351e7eb2f38093bb95fadcae2520c6f023",
    sourceDate: "July 23, 2026",
    sha256:
      "9f33a99ca5ba7c2047338409244d7e2048e92ae9da8313efa9f5fac21a6e2d32",
    width: 1024,
    height: 1536,
  },
  {
    id: "sable",
    name: "Sable",
    role: "Marksman",
    image: "/units/sable.png",
    status: "reinspect",
    statusLabel: "Reinspection pending",
    sourceLabel: "Current Phase II master",
    stage: "Phase II candidate",
    sourcePath: "assets/concepts/phase2_calibration/sable/sable_master.png",
    sourceCommit: "4b4f2630232155160e43820aac416158816ff346",
    sourceDate: "July 22, 2026",
    sha256:
      "d079556a5ec2050ff23cab8d8414d1fb3705e231f4c55cedbecde448d53bfd47",
    width: 1024,
    height: 1536,
  },
];

const PHASE2_COMMITS = {
  p2_01: "f4dc6671854de5acdb27ef2742008d80bfe610de",
  p2_02: "4b4f2630232155160e43820aac416158816ff346",
  p2_03: "9d03d7c9c67a11200aa77a8ad1ea4dc800db679a",
} as const;

type HistoricalVersion = Omit<ConceptVersion, "status">;

const historicalVersions: Record<string, HistoricalVersion[]> = {
  korath: [
    {
      id: "p2-01",
      referenceName: "Korath P2-01 — Initial Calibration",
      image: "/versions/korath/p2-01.png",
      stage: "Phase II initial calibration",
      sourcePath: "assets/concepts/phase2_calibration/korath/korath_master.png",
      sourceCommit: PHASE2_COMMITS.p2_01,
      sourceDate: "July 21, 2026",
      sha256: "01ed4c99121c6a57568cf91170561d4686f2e18ee59b9b6c2c45327d3e4453a6",
      width: 1024,
      height: 1536,
    },
  ],
  veyra: [
    {
      id: "p2-01",
      referenceName: "Veyra P2-01 — Closed Egg / Initial Calibration",
      image: "/versions/veyra/p2-01.png",
      stage: "Phase II initial calibration",
      sourcePath: "assets/concepts/phase2_calibration/veyra/veyra_master.png",
      sourceCommit: PHASE2_COMMITS.p2_01,
      sourceDate: "July 21, 2026",
      sha256: "0e5b4b602a478551df31c337e5eefdedb5946a7a790303d43ececb146ed81e37",
      width: 1122,
      height: 1402,
    },
    {
      id: "p2-02",
      referenceName: "Veyra P2-02 — Open Shell / Board-Era Revision",
      image: "/versions/veyra/p2-02.png",
      stage: "Phase II board-era revision",
      sourcePath: "assets/concepts/phase2_calibration/veyra/veyra_master.png",
      sourceCommit: PHASE2_COMMITS.p2_02,
      sourceDate: "July 22, 2026",
      sha256: "71f87981ce087511839c9732714ea51ea7ce57d0bf708a4bb738b5bf91544ebd",
      width: 1122,
      height: 1402,
    },
  ],
  cashmere: [
    {
      id: "p2-01",
      referenceName: "Cashmere P2-01 — Initial Calibration",
      image: "/versions/cashmere/p2-01.png",
      stage: "Phase II initial calibration",
      sourcePath: "assets/concepts/phase2_calibration/cashmere/cashmere_master.png",
      sourceCommit: PHASE2_COMMITS.p2_01,
      sourceDate: "July 21, 2026",
      sha256: "32790ebc5d03c6c356f37d2a9ce24712f39bca51f88d2394c029bfe1b840fdba",
      width: 887,
      height: 1774,
    },
    {
      id: "p2-02",
      referenceName: "Cashmere P2-02 — Board-Era Revision",
      image: "/versions/cashmere/p2-02.png",
      stage: "Phase II board-era revision",
      sourcePath: "assets/concepts/phase2_calibration/cashmere/cashmere_master.png",
      sourceCommit: PHASE2_COMMITS.p2_02,
      sourceDate: "July 22, 2026",
      sha256: "8c1b8b7d8b2c3cebb337ac730afbdbfb925b93414ffcc0e565e5783700858a21",
      width: 1024,
      height: 1536,
    },
  ],
  pilfer: [
    {
      id: "p2-01",
      referenceName: "Pilfer P2-01 — Initial Calibration",
      image: "/versions/pilfer/p2-01.png",
      stage: "Phase II initial calibration",
      sourcePath: "assets/concepts/phase2_calibration/pilfer/pilfer_master.png",
      sourceCommit: PHASE2_COMMITS.p2_01,
      sourceDate: "July 21, 2026",
      sha256: "726bf2e3f8fe6c94f23006272dfdf23aa30f1986ad455a0d8bdeabdc00ab72d9",
      width: 1024,
      height: 1536,
    },
  ],
  nyxa: [
    {
      id: "p2-01",
      referenceName: "Nyxa P2-01 — Initial Calibration",
      image: "/versions/nyxa/p2-01.png",
      stage: "Phase II initial calibration",
      sourcePath: "assets/concepts/phase2_calibration/nyxa/nyxa_master.png",
      sourceCommit: PHASE2_COMMITS.p2_01,
      sourceDate: "July 21, 2026",
      sha256: "575e23c763c0a90c4c45451b2a73b4f75bfee85c778d923efca226a07ca14438",
      width: 1024,
      height: 1536,
    },
  ],
  creep: [],
  knoll: [
    {
      id: "p2-01",
      referenceName: "Knoll P2-01 — Initial Calibration",
      image: "/versions/knoll/p2-01.png",
      stage: "Phase II initial calibration",
      sourcePath: "assets/concepts/phase2_calibration/knoll/knoll_master.png",
      sourceCommit: PHASE2_COMMITS.p2_01,
      sourceDate: "July 21, 2026",
      sha256: "8854fc47872fcb72668cc89639dad6cdd417b8dde0a10572f2321d980582e87c",
      width: 1024,
      height: 1536,
    },
    {
      id: "p2-02",
      referenceName: "Knoll P2-02 — Board-Era Revision",
      image: "/versions/knoll/p2-02.png",
      stage: "Phase II board-era revision",
      sourcePath: "assets/concepts/phase2_calibration/knoll/knoll_master.png",
      sourceCommit: PHASE2_COMMITS.p2_02,
      sourceDate: "July 22, 2026",
      sha256: "5063997597700dd1019625aeadf2e642e6928193972a33d13058f9ea7a3ae70b",
      width: 1024,
      height: 1536,
    },
  ],
  quillith: [
    {
      id: "p2-01",
      referenceName: "Quillith P2-01 — Initial Calibration",
      image: "/versions/quillith/p2-01.png",
      stage: "Phase II initial calibration",
      sourcePath: "assets/concepts/phase2_calibration/quillith/quillith_master.png",
      sourceCommit: PHASE2_COMMITS.p2_01,
      sourceDate: "July 21, 2026",
      sha256: "3cf3f8ba034a5e373b0432c2881fcde33fc5477b625957422c79cb6a875323a8",
      width: 1024,
      height: 1536,
    },
    {
      id: "p2-02",
      referenceName: "Quillith P2-02 — Board-Era Revision",
      image: "/versions/quillith/p2-02.png",
      stage: "Phase II board-era revision",
      sourcePath: "assets/concepts/phase2_calibration/quillith/quillith_master.png",
      sourceCommit: PHASE2_COMMITS.p2_02,
      sourceDate: "July 22, 2026",
      sha256: "317bd83f272bb25e0e6e1500f9c6e2f735bed52e23091d7a301bbee3725aac72",
      width: 1023,
      height: 1537,
    },
  ],
  kett: [
    {
      id: "p2-01",
      referenceName: "Kett P2-01 — Initial Calibration",
      image: "/versions/kett/p2-01.png",
      stage: "Phase II initial calibration",
      sourcePath: "assets/concepts/phase2_calibration/kett/kett_master.png",
      sourceCommit: PHASE2_COMMITS.p2_01,
      sourceDate: "July 21, 2026",
      sha256: "eb06723d9b7464900e525a2f462c674fecfb28fc5138dee6e5fc5f2947897dd5",
      width: 1023,
      height: 1537,
    },
  ],
  luna: [
    {
      id: "p2-01",
      referenceName: "Luna P2-01 — Initial Calibration",
      image: "/versions/luna/p2-01.png",
      stage: "Phase II initial calibration",
      sourcePath: "assets/concepts/phase2_calibration/luna/luna_master.png",
      sourceCommit: PHASE2_COMMITS.p2_01,
      sourceDate: "July 21, 2026",
      sha256: "39e003f87050234309d127c2bc4f6fddb3f34b4feba6b698bd4872db35065b5c",
      width: 941,
      height: 1672,
    },
    {
      id: "p2-02",
      referenceName: "Luna P2-02 — Board-Era Revision",
      image: "/versions/luna/p2-02.png",
      stage: "Phase II board-era revision",
      sourcePath: "assets/concepts/phase2_calibration/luna/luna_master.png",
      sourceCommit: PHASE2_COMMITS.p2_02,
      sourceDate: "July 22, 2026",
      sha256: "c65b8e095c735139f2f1aa22ddc664c0dedaedfd68aacc790aad9a394880420d",
      width: 1024,
      height: 1536,
    },
  ],
  malachor: [
    {
      id: "p2-01",
      referenceName: "Malachor P2-01 — Initial Calibration",
      image: "/versions/malachor/p2-01.png",
      stage: "Phase II initial calibration",
      sourcePath: "assets/concepts/phase2_calibration/malachor/malachor_master.png",
      sourceCommit: PHASE2_COMMITS.p2_01,
      sourceDate: "July 21, 2026",
      sha256: "71b730e0f272c1c0190973296daa3d4ab4a643424a7b3e946dc62467953ccef1",
      width: 1024,
      height: 1536,
    },
    {
      id: "p2-02",
      referenceName: "Malachor P2-02 — Board-Era Revision",
      image: "/versions/malachor/p2-02.png",
      stage: "Phase II board-era revision",
      sourcePath: "assets/concepts/phase2_calibration/malachor/malachor_master.png",
      sourceCommit: PHASE2_COMMITS.p2_02,
      sourceDate: "July 22, 2026",
      sha256: "d110e469af8426ad2c4d8369c870b00b03c6f75100affe32eccf6f3bba120954",
      width: 1254,
      height: 1254,
    },
    {
      id: "p2-03",
      referenceName: "Malachor P2-03 — Repaired Reapproval Cut",
      image: "/versions/malachor/p2-03.png",
      stage: "Phase II repaired reapproval cut",
      sourcePath: "assets/concepts/phase2_calibration/malachor/malachor_master.png",
      sourceCommit: PHASE2_COMMITS.p2_03,
      sourceDate: "July 22, 2026",
      sha256: "6645bc2a1dbe7f682bed7e8211937a9592dcbba44037c86a6cb8cf9c2f95158f",
      width: 1536,
      height: 1024,
    },
  ],
  sable: [
    {
      id: "p2-01",
      referenceName: "Sable P2-01 — Initial Calibration",
      image: "/versions/sable/p2-01.png",
      stage: "Phase II initial calibration",
      sourcePath: "assets/concepts/phase2_calibration/sable/sable_master.png",
      sourceCommit: PHASE2_COMMITS.p2_01,
      sourceDate: "July 21, 2026",
      sha256: "8798ba2d61a5f42dd73a5d107a50f10febd8239d1322ff11d76b9e51ffc03a77",
      width: 1024,
      height: 1536,
    },
  ],
};

const currentVersionIds: Record<string, string> = {
  korath: "p2-02",
  veyra: "p2-03",
  cashmere: "p2-03",
  pilfer: "p2-02",
  nyxa: "p2-02",
  creep: "p2-01",
  knoll: "s3-01",
  quillith: "p2-03",
  kett: "p2-02",
  luna: "p2-03",
  malachor: "s3-01",
  sable: "p2-02",
};

function currentReferenceName(concept: CurrentUnitConcept): string {
  const versionId = currentVersionIds[concept.id].toUpperCase();
  if (concept.id === "veyra") {
    return "Veyra P2-03 — Cocoon Core / Repaired Reapproval Cut";
  }
  if (concept.id === "knoll") {
    return "Knoll S3-01 — Foreclosure Press";
  }
  if (concept.id === "malachor") {
    return "Malachor S3-01 — Living Siege Cage";
  }
  const suffix =
    versionId === "P2-01"
      ? "Initial Calibration"
      : versionId === "P2-02"
        ? "Board-Era Revision"
        : "Repaired Reapproval Cut";
  return `${concept.name} ${versionId} — ${suffix}`;
}

export const unitConcepts: UnitConcept[] = currentUnitConcepts.map((concept) => {
  const currentVersion: ConceptVersion = {
    id: currentVersionIds[concept.id],
    referenceName: currentReferenceName(concept),
    image: concept.image,
    stage: concept.stage,
    status:
      concept.status === "locked" ? "locked_direction" : "current_candidate",
    sourcePath: concept.sourcePath,
    sourceCommit: concept.sourceCommit,
    sourceDate: concept.sourceDate,
    sha256: concept.sha256,
    width: concept.width,
    height: concept.height,
  };

  return {
    ...concept,
    currentVersionId: currentVersion.id,
    versions: [
      ...(historicalVersions[concept.id] ?? []).map((version) => ({
        ...version,
        status: "historical_candidate" as const,
      })),
      currentVersion,
    ],
  };
});

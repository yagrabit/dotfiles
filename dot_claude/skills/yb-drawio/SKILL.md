---
name: yb-drawio
description: Generate draw.io diagrams as .drawio files, optionally export to PNG/SVG/PDF with embedded XML
user-invocable: true
---

# Draw.io Diagram Skill

Generate draw.io diagrams as native `.drawio` files. Optionally export to PNG, SVG, or PDF with the diagram XML embedded (so the exported file remains editable in draw.io).

## How to create a diagram

1. **Generate draw.io XML** in mxGraphModel format for the requested diagram
2. **Write the XML** to a `.drawio` file in the current working directory using the Write tool
3. **If the user requested an export format** (png, svg, pdf), export using the draw.io CLI with `--embed-diagram`, then delete the source `.drawio` file
4. **Open the result** — the exported file if exported, or the `.drawio` file otherwise

## Choosing the output format

Check the user's request for a format preference. Examples:

- `/drawio create a flowchart` → `flowchart.drawio`
- `/drawio png flowchart for login` → `login-flow.drawio.png`
- `/drawio svg: ER diagram` → `er-diagram.drawio.svg`
- `/drawio pdf architecture overview` → `architecture-overview.drawio.pdf`

If no format is mentioned, just write the `.drawio` file and open it in draw.io. The user can always ask to export later.

### Supported export formats

| Format | Embed XML | Notes |
|--------|-----------|-------|
| `png` | Yes (`-e`) | Viewable everywhere, editable in draw.io |
| `svg` | Yes (`-e`) | Scalable, editable in draw.io |
| `pdf` | Yes (`-e`) | Printable, editable in draw.io |
| `jpg` | No | Lossy, no embedded XML support |

PNG, SVG, and PDF all support `--embed-diagram` — the exported file contains the full diagram XML, so opening it in draw.io recovers the editable diagram.

## draw.io CLI

The draw.io desktop app includes a command-line interface for exporting.

### Locating the CLI

Try `drawio` first (works if on PATH), then fall back to the platform-specific path:

- **macOS**: `/Applications/draw.io.app/Contents/MacOS/draw.io`
- **Linux**: `drawio` (typically on PATH via snap/apt/flatpak)
- **Windows**: `"C:\Program Files\draw.io\draw.io.exe"`

Use `which drawio` (or `where drawio` on Windows) to check if it's on PATH before falling back.

### Export command

```bash
drawio -x -f <format> -e -b 10 -o <output> <input.drawio>
```

Key flags:
- `-x` / `--export`: export mode
- `-f` / `--format`: output format (png, svg, pdf, jpg)
- `-e` / `--embed-diagram`: embed diagram XML in the output (PNG, SVG, PDF only)
- `-o` / `--output`: output file path
- `-b` / `--border`: border width around diagram (default: 0)
- `-t` / `--transparent`: transparent background (PNG only)
- `-s` / `--scale`: scale the diagram size
- `--width` / `--height`: fit into specified dimensions (preserves aspect ratio)
- `-a` / `--all-pages`: export all pages (PDF only)
- `-p` / `--page-index`: select a specific page (1-based)

### Opening the result

- **macOS**: `open <file>`
- **Linux**: `xdg-open <file>`
- **Windows**: `start <file>`

## File naming

- Use a descriptive filename based on the diagram content (e.g., `login-flow`, `database-schema`)
- Use lowercase with hyphens for multi-word names
- For export, use double extensions: `name.drawio.png`, `name.drawio.svg`, `name.drawio.pdf` — this signals the file contains embedded diagram XML
- After a successful export, delete the intermediate `.drawio` file — the exported file contains the full diagram

## XML format

A `.drawio` file is native mxGraphModel XML. Always generate XML directly — Mermaid and CSV formats require server-side conversion and cannot be saved as native files.

### Basic structure

Every diagram must have this structure:

```xml
<mxGraphModel>
  <root>
    <mxCell id="0"/>
    <mxCell id="1" parent="0"/>
    <!-- Diagram cells go here with parent="1" -->
  </root>
</mxGraphModel>
```

- Cell `id="0"` is the root layer
- Cell `id="1"` is the default parent layer
- All diagram elements use `parent="1"` unless using multiple layers

### Common styles

**Rounded rectangle:**
```xml
<mxCell id="2" value="Label" style="rounded=1;whiteSpace=wrap;" vertex="1" parent="1">
  <mxGeometry x="100" y="100" width="120" height="60" as="geometry"/>
</mxCell>
```

**Diamond (decision):**
```xml
<mxCell id="3" value="Condition?" style="rhombus;whiteSpace=wrap;" vertex="1" parent="1">
  <mxGeometry x="100" y="200" width="120" height="80" as="geometry"/>
</mxCell>
```

**Arrow (edge):**
```xml
<mxCell id="4" value="" style="edgeStyle=orthogonalEdgeStyle;" edge="1" source="2" target="3" parent="1">
  <mxGeometry relative="1" as="geometry"/>
</mxCell>
```

**Labeled arrow:**
```xml
<mxCell id="5" value="Yes" style="edgeStyle=orthogonalEdgeStyle;" edge="1" source="3" target="6" parent="1">
  <mxGeometry relative="1" as="geometry"/>
</mxCell>
```

### Useful style properties

| Property | Values | Use for |
|----------|--------|---------|
| `rounded=1` | 0 or 1 | Rounded corners |
| `whiteSpace=wrap` | wrap | Text wrapping |
| `fillColor=#dae8fc` | Hex color | Background color |
| `strokeColor=#6c8ebf` | Hex color | Border color |
| `fontColor=#333333` | Hex color | Text color |
| `shape=cylinder3` | shape name | Database cylinders |
| `shape=mxgraph.flowchart.document` | shape name | Document shapes |
| `ellipse` | style keyword | Circles/ovals |
| `rhombus` | style keyword | Diamonds |
| `edgeStyle=orthogonalEdgeStyle` | style keyword | Right-angle connectors |
| `edgeStyle=elbowEdgeStyle` | style keyword | Elbow connectors |
| `dashed=1` | 0 or 1 | Dashed lines |
| `swimlane` | style keyword | Swimlane containers |
| `group` | style keyword | Invisible container (pointerEvents=0) |
| `container=1` | 0 or 1 | Enable container behavior on any shape |
| `pointerEvents=0` | 0 or 1 | Prevent container from capturing child connections |

## Edge routing

**CRITICAL: Every edge `mxCell` must contain a `<mxGeometry relative="1" as="geometry" />` child element**, even when there are no waypoints. Self-closing edge cells (e.g. `<mxCell ... edge="1" ... />`) are invalid and will not render correctly. Always use the expanded form:
```xml
<mxCell id="e1" edge="1" parent="1" source="a" target="b" style="...">
  <mxGeometry relative="1" as="geometry" />
</mxCell>
```

draw.io does **not** have built-in collision detection for edges. Plan layout and routing carefully:

- Use `edgeStyle=orthogonalEdgeStyle` for right-angle connectors (most common)
- **Space nodes generously** — at least 60px apart, prefer 200px horizontal / 120px vertical gaps
- Use `exitX`/`exitY` and `entryX`/`entryY` (values 0–1) to control which side of a node an edge connects to. Spread connections across different sides to prevent overlap
- **Leave room for arrowheads**: The final straight segment of an edge (between the last bend and the target shape, or between the source shape and the first bend) must be long enough to fit the arrowhead. The default arrow size is 6px (configurable via `startSize`/`endSize` styles). If the final segment is too short, the arrowhead overlaps the bend and looks broken. Ensure at least 20px of straight segment before the target and after the source when placing waypoints or positioning nodes
- When using `orthogonalEdgeStyle`, the auto-router places bends automatically — if source and target are close together or nearly aligned on one axis, the router may place a bend very close to a shape, leaving no room for the arrow. Fix this by either increasing node spacing or adding explicit waypoints that keep the final segment long enough
- Add explicit **waypoints** when edges would overlap:
  ```xml
  <mxCell id="e1" style="edgeStyle=orthogonalEdgeStyle;" edge="1" parent="1" source="a" target="b">
    <mxGeometry relative="1" as="geometry">
      <Array as="points">
        <mxPoint x="300" y="150"/>
        <mxPoint x="300" y="250"/>
      </Array>
    </mxGeometry>
  </mxCell>
  ```
- Use `rounded=1` on edges for cleaner bends
- Use `jettySize=auto` for better port spacing on orthogonal edges
- Align all nodes to a grid (multiples of 10)

## Containers and groups

For architecture diagrams or any diagram with nested elements, use draw.io's proper parent-child containment — do **not** just place shapes on top of larger shapes.

### How containment works

Set `parent="containerId"` on child cells. Children use **relative coordinates** within the container.

### Container types

| Type | Style | When to use |
|------|-------|-------------|
| **Group** (invisible) | `group;` | No visual border needed, container has no connections. Includes `pointerEvents=0` so child connections are not captured |
| **Swimlane** (titled) | `swimlane;startSize=30;` | Container needs a visible title bar/header, or the container itself has connections |
| **Custom container** | Add `container=1;pointerEvents=0;` to any shape style | Any shape acting as a container without its own connections |

### Key rules

- **Always add `pointerEvents=0;`** to container styles that should not capture connections being rewired between children
- Only omit `pointerEvents=0` when the container itself needs to be connectable — in that case, use `swimlane` style which handles this correctly (the client area is transparent for mouse events while the header remains connectable)
- Children must set `parent="containerId"` and use coordinates **relative to the container**

### Example: Architecture container with swimlane

```xml
<mxCell id="svc1" value="User Service" style="swimlane;startSize=30;fillColor=#dae8fc;strokeColor=#6c8ebf;" vertex="1" parent="1">
  <mxGeometry x="100" y="100" width="300" height="200" as="geometry"/>
</mxCell>
<mxCell id="api1" value="REST API" style="rounded=1;whiteSpace=wrap;" vertex="1" parent="svc1">
  <mxGeometry x="20" y="40" width="120" height="60" as="geometry"/>
</mxCell>
<mxCell id="db1" value="Database" style="shape=cylinder3;whiteSpace=wrap;" vertex="1" parent="svc1">
  <mxGeometry x="160" y="40" width="120" height="60" as="geometry"/>
</mxCell>
```

### Example: Invisible group container

```xml
<mxCell id="grp1" value="" style="group;" vertex="1" parent="1">
  <mxGeometry x="100" y="100" width="300" height="200" as="geometry"/>
</mxCell>
<mxCell id="c1" value="Component A" style="rounded=1;whiteSpace=wrap;" vertex="1" parent="grp1">
  <mxGeometry x="10" y="10" width="120" height="60" as="geometry"/>
</mxCell>
```

## Style reference

For the complete draw.io style reference: https://www.drawio.com/doc/faq/drawio-style-reference.html

For the XML Schema Definition (XSD): https://www.drawio.com/assets/mxfile.xsd

## CRITICAL: XML well-formedness

- **NEVER use double hyphens (`--`) inside XML comments.** `--` is illegal inside `<!-- -->` per the XML spec and causes parse errors. Use single hyphens or rephrase.
- Escape special characters in attribute values: `&amp;`, `&lt;`, `&gt;`, `&quot;`
- Always use unique `id` values for each `mxCell`

## AWS architecture diagrams with official icons

When generating AWS architecture diagrams, ALWAYS use the built-in `mxgraph.aws4.*` icon library instead of plain rectangles. This produces professional diagrams with official AWS icons.

### Resource Icon (service icons)

Standard size: **78x78**. Use `shape=mxgraph.aws4.resourceIcon` with `resIcon` for the specific service.

```xml
<mxCell id="lambda1" value="Lambda" style="sketch=0;points=[[0,0,0],[0.25,0,0],[0.5,0,0],[0.75,0,0],[1,0,0],[0,1,0],[0.25,1,0],[0.5,1,0],[0.75,1,0],[1,1,0],[0,0.25,0],[0,0.5,0],[0,0.75,0],[1,0.25,0],[1,0.5,0],[1,0.75,0]];outlineConnect=0;fontColor=#232F3E;strokeColor=#ffffff;dashed=0;verticalLabelPosition=bottom;verticalAlign=top;align=center;html=1;fontSize=12;fontStyle=0;aspect=fixed;shape=mxgraph.aws4.resourceIcon;resIcon=mxgraph.aws4.lambda;fillColor=#ED7100;" vertex="1" parent="1">
  <mxGeometry x="100" y="100" width="78" height="78" as="geometry"/>
</mxCell>
```

### Service icon names (resIcon values)

| Service | resIcon=mxgraph.aws4.XXX | fillColor (category) |
|---------|--------------------------|----------------------|
| Lambda | `lambda` | `#ED7100` (Compute) |
| API Gateway | `api_gateway` | `#E7157B` (App Integration) |
| CloudFront | `cloudfront` | `#8C4FFF` (Networking) |
| Route 53 | `route_53` | `#8C4FFF` (Networking) |
| S3 | `s3` | `#7AA116` (Storage) |
| DynamoDB | `dynamodb` | `#3B48CC` (Database) |
| Aurora | `aurora` | `#3B48CC` (Database) |
| RDS | `rds` | `#3B48CC` (Database) |
| Cognito | `cognito` | `#DD344C` (Security) |
| EventBridge | `eventbridge` | `#E7157B` (App Integration) |
| CloudWatch | `cloudwatch` | `#E7157B` (Management) |
| AppSync | `appsync` | `#E7157B` (App Integration) |
| ACM | `certificate_manager` | `#DD344C` (Security) |
| EC2 | `ec2` | `#ED7100` (Compute) |
| ECS | `ecs` | `#ED7100` (Compute) |
| EKS | `eks` | `#ED7100` (Compute) |
| Fargate | `fargate` | `#ED7100` (Compute) |
| ALB | `application_load_balancer` | `#8C4FFF` (Networking) |
| NLB | `network_load_balancer` | `#8C4FFF` (Networking) |
| Internet Gateway | `internet_gateway` | `#8C4FFF` (Networking) |
| NAT Gateway | `nat_gateway` | `#8C4FFF` (Networking) |
| SNS | `sns` | `#E7157B` (App Integration) |
| SQS | `sqs` | `#E7157B` (App Integration) |
| Step Functions | `step_functions` | `#E7157B` (App Integration) |
| KMS | `key_management_service` | `#DD344C` (Security) |
| WAF | `waf` | `#DD344C` (Security) |
| Secrets Manager | `secrets_manager` | `#DD344C` (Security) |
| IAM | `iam` | `#DD344C` (Security) |
| CloudFormation | `cloudformation` | `#E7157B` (Management) |
| Bedrock | `bedrock` | `#01A88D` (AI/ML) |
| ECR | `ecr` | `#ED7100` (Compute) |
| VPC | `vpc` | `#8C4FFF` (Networking) |

### Category colors

| Category | fillColor |
|----------|-----------|
| Compute | `#ED7100` |
| Database | `#3B48CC` |
| Storage | `#7AA116` |
| Networking | `#8C4FFF` |
| Security | `#DD344C` |
| App Integration | `#E7157B` |
| Management | `#E7157B` |
| AI/ML | `#01A88D` |
| General | `#232F3D` |

### AWS Group containers

Use these for VPC, Region, Subnet, etc. All groups require `container=1;pointerEvents=0;collapsible=0;recursiveResize=0`. Children use relative coordinates with `parent="groupId"`.

Common style prefix for all groups:
```
points=[[0,0],[0.25,0],[0.5,0],[0.75,0],[1,0],[1,0.25],[1,0.5],[1,0.75],[1,1],[0.75,1],[0.5,1],[0.25,1],[0,1],[0,0.75],[0,0.5],[0,0.25]];outlineConnect=0;gradientColor=none;html=1;whiteSpace=wrap;fontSize=12;fontStyle=0;container=1;pointerEvents=0;collapsible=0;recursiveResize=0;
```

Append group-specific styles:

| Group | Additional style |
|-------|------------------|
| AWS Cloud | `shape=mxgraph.aws4.group;grIcon=mxgraph.aws4.group_aws_cloud_alt;strokeColor=#232F3E;fillColor=none;verticalAlign=top;align=left;spacingLeft=30;fontColor=#232F3E;dashed=0;` |
| Region | `shape=mxgraph.aws4.group;grIcon=mxgraph.aws4.group_region;strokeColor=#00A4A6;fillColor=none;verticalAlign=top;align=left;spacingLeft=30;fontColor=#147EBA;dashed=1;` |
| VPC | `shape=mxgraph.aws4.group;grIcon=mxgraph.aws4.group_vpc2;strokeColor=#8C4FFF;fillColor=none;verticalAlign=top;align=left;spacingLeft=30;fontColor=#AAB7B8;dashed=0;` |
| Public Subnet | `shape=mxgraph.aws4.group;grIcon=mxgraph.aws4.group_security_group;grStroke=0;strokeColor=#7AA116;fillColor=#F2F6E8;verticalAlign=top;align=left;spacingLeft=30;fontColor=#248814;dashed=0;` |
| Private Subnet | `shape=mxgraph.aws4.group;grIcon=mxgraph.aws4.group_security_group;grStroke=0;strokeColor=#00A4A6;fillColor=#E6F6F7;verticalAlign=top;align=left;spacingLeft=30;fontColor=#147EBA;dashed=0;` |
| Security Group | `fillColor=none;strokeColor=#DD3522;verticalAlign=top;align=left;spacingLeft=10;fontColor=#DD3522;dashed=0;` (no grIcon) |
| Availability Zone | `fillColor=none;strokeColor=#147EBA;verticalAlign=top;align=left;spacingLeft=10;fontColor=#147EBA;dashed=1;` (no grIcon) |
| Auto Scaling Group | `shape=mxgraph.aws4.group;grIcon=mxgraph.aws4.group_auto_scaling_group;strokeColor=#D86613;fillColor=none;verticalAlign=top;align=left;spacingLeft=30;fontColor=#D86613;dashed=1;` |
| AWS Account | `shape=mxgraph.aws4.group;grIcon=mxgraph.aws4.group_account;strokeColor=#CD2264;fillColor=none;verticalAlign=top;align=left;spacingLeft=30;fontColor=#CD2264;dashed=0;` |

### Full example: AWS architecture with icons and groups

```xml
<mxGraphModel>
  <root>
    <mxCell id="0"/>
    <mxCell id="1" parent="0"/>

    <!-- AWS Cloud -->
    <mxCell id="cloud" value="AWS Cloud" style="points=[[0,0],[0.25,0],[0.5,0],[0.75,0],[1,0],[1,0.25],[1,0.5],[1,0.75],[1,1],[0.75,1],[0.5,1],[0.25,1],[0,1],[0,0.75],[0,0.5],[0,0.25]];outlineConnect=0;gradientColor=none;html=1;whiteSpace=wrap;fontSize=12;fontStyle=0;container=1;pointerEvents=0;collapsible=0;recursiveResize=0;shape=mxgraph.aws4.group;grIcon=mxgraph.aws4.group_aws_cloud_alt;strokeColor=#232F3E;fillColor=none;verticalAlign=top;align=left;spacingLeft=30;fontColor=#232F3E;dashed=0;" vertex="1" parent="1">
      <mxGeometry x="20" y="20" width="800" height="600" as="geometry"/>
    </mxCell>

    <!-- Region (child of cloud) -->
    <mxCell id="region" value="ap-northeast-1" style="points=[[0,0],[0.25,0],[0.5,0],[0.75,0],[1,0],[1,0.25],[1,0.5],[1,0.75],[1,1],[0.75,1],[0.5,1],[0.25,1],[0,1],[0,0.75],[0,0.5],[0,0.25]];outlineConnect=0;gradientColor=none;html=1;whiteSpace=wrap;fontSize=12;fontStyle=0;container=1;pointerEvents=0;collapsible=0;recursiveResize=0;shape=mxgraph.aws4.group;grIcon=mxgraph.aws4.group_region;strokeColor=#00A4A6;fillColor=none;dashed=1;verticalAlign=top;align=left;spacingLeft=30;fontColor=#147EBA;" vertex="1" parent="cloud">
      <mxGeometry x="20" y="40" width="760" height="540" as="geometry"/>
    </mxCell>

    <!-- VPC (child of region) -->
    <mxCell id="vpc" value="VPC" style="points=[[0,0],[0.25,0],[0.5,0],[0.75,0],[1,0],[1,0.25],[1,0.5],[1,0.75],[1,1],[0.75,1],[0.5,1],[0.25,1],[0,1],[0,0.75],[0,0.5],[0,0.25]];outlineConnect=0;gradientColor=none;html=1;whiteSpace=wrap;fontSize=12;fontStyle=0;container=1;pointerEvents=0;collapsible=0;recursiveResize=0;shape=mxgraph.aws4.group;grIcon=mxgraph.aws4.group_vpc2;strokeColor=#8C4FFF;fillColor=none;verticalAlign=top;align=left;spacingLeft=30;fontColor=#AAB7B8;dashed=0;" vertex="1" parent="region">
      <mxGeometry x="20" y="40" width="720" height="480" as="geometry"/>
    </mxCell>

    <!-- Lambda icon (child of vpc, 78x78) -->
    <mxCell id="lambda1" value="Lambda" style="sketch=0;points=[[0,0,0],[0.25,0,0],[0.5,0,0],[0.75,0,0],[1,0,0],[0,1,0],[0.25,1,0],[0.5,1,0],[0.75,1,0],[1,1,0],[0,0.25,0],[0,0.5,0],[0,0.75,0],[1,0.25,0],[1,0.5,0],[1,0.75,0]];outlineConnect=0;fontColor=#232F3E;strokeColor=#ffffff;dashed=0;verticalLabelPosition=bottom;verticalAlign=top;align=center;html=1;fontSize=12;fontStyle=0;aspect=fixed;shape=mxgraph.aws4.resourceIcon;resIcon=mxgraph.aws4.lambda;fillColor=#ED7100;" vertex="1" parent="vpc">
      <mxGeometry x="100" y="100" width="78" height="78" as="geometry"/>
    </mxCell>

    <!-- Edge -->
    <mxCell id="e1" style="edgeStyle=orthogonalEdgeStyle;rounded=1;" edge="1" source="lambda1" target="other" parent="1">
      <mxGeometry relative="1" as="geometry"/>
    </mxCell>
  </root>
</mxGraphModel>
```

### Layout tips for AWS diagrams

- Nest groups properly: AWS Cloud > Region > VPC > Subnet > resources
- Resource icons are 78x78, leave at least 120px between icons
- Place external services (users, on-premises) outside the AWS Cloud group
- Use the Users icon for internet users: `shape=mxgraph.aws4.resourceIcon;resIcon=mxgraph.aws4.users;fillColor=#232F3D`
- Definition order: containers first, then edges, then vertices (ensures labels render above arrows)
